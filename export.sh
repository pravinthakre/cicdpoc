#V1.0 - Last Updated 20/02/2020 by Pravin Thakre

#Params to add to build: 
#OIC_USERNAME
#OICPASSWORD
#OIC_SOURCE_ENV

chmod 755 CONFIGS/env-${OIC_SOURCE_ENV}
source ./CONFIGS/env-${OIC_SOURCE_ENV}


#loop through integrations to pull
for ((integration=0; integration<${#GET_INTEGRATIONS[@]}; integration=integration+2))
do
  curl -u ${OIC_USERNAME}:${OIC_PASSWORD} -H “Content-Type:octet-stream” -X GET ${OIC_BASE_URL}/ic/api/integration/v1/integrations/${GET_INTEGRATIONS[$integration]}\|${GET_INTEGRATIONS[$integration+1]}/archive -v --output ${GET_INTEGRATIONS[$integration]}.iar -v
done


#loop through packages to export
for package in ${GET_PACKAGES}
do

  #if package does not exist in our directory, create the directory
  if [ ! -d "${package}_package" ]
  then
      mkdir ${package}_package
  fi
  #enter the repository
  cd ${package}_package


  #Download the Par file for package
  curl -u ${OIC_USERNAME}:${OIC_PASSWORD} -H “Content-Type:octet-stream” -X GET ${OIC_BASE_URL}/ic/api/integration/v1/packages/${package}/archive -v --output ${package}.par 

  #get Package Data
  curl -u ${OIC_USERNAME}:${OIC_PASSWORD} -H “Content-Type:octet-stream” -X GET ${OIC_BASE_URL}/ic/api/integration/v1/packages/${package} -v --output ${package}.json
  
  #Loop through each integration in package
  max=$(node -pe 'JSON.parse(process.argv[1]).countOfIntegrations' "$(cat "${package}".json)")
  for ((i=0;i<max;i++));
  do
    integration=$(node -pe 'JSON.parse(process.argv[1]).integrations['${i}'].id' "$(cat "${package}".json)")
    curl -u ${OIC_USERNAME}:${OIC_PASSWORD} -H “Content-Type:octet-stream” -X GET ${OIC_BASE_URL}/ic/api/integration/v1/integrations/${integration} --output integration.json
    len=$(node -pe 'JSON.parse(process.argv[1]).dependencies.connections.length' "$(cat integration.json)")
    
    #loop through each connection for all integrations and download their Jsons
    for ((j=0;j<len;j++));
    do
        
        connector=$(node -pe 'JSON.parse(process.argv[1]).dependencies.connections['${j}'].id' "$(cat integration.json)")
        
        curl -u ${OIC_USERNAME}:${OIC_PASSWORD} -H “Content-Type:octet-stream” -X GET ${OIC_BASE_URL}/ic/api/integration/v1/connections/${connector} -v --output connection.json
        
        #Edit Jsons to be immediately configurable
        sed '5!d' connection.json > ${connector}.json
            
node<<EOF

        const fs = require('fs');
        const http = require("https");
        const data = require('./${connector}.json')
        var auth = 'Basic ' + Buffer.from('${OIC_USERNAME}:${OIC_PASSWORD}').toString('base64');
        delete data.adapterType.type
        var dataString=JSON.stringify(data)
        fs.writeFileSync('${connector}.json',dataString)
        
        if(data.connectionProperties != undefined){
          if(data.connectionProperties[0].attachment != undefined){
            attachmentName = data.connectionProperties[0].attachment.attachmentName
            propertyName = data.connectionProperties[0].attachment.propertyName
            console.log("attach: " + attachmentName + "\nprop: " + propertyName)
            //Write to json to make sure it is able to be immediately re-uploaded
//            var dataString=JSON.stringify(data)
            console.log('${connector}.json')

        
            //API call to get attachment
            var options = {
              "method": "GET",
              "hostname":"integration-orasenatdpltintegration02.integration.ocp.oraclecloud.com",
              "port": "443",
              "path": "/ic/api/integration/v1/connections/${connector}/attachments/"+propertyName,
              "headers": {
                  "Authorization": auth,
                  "Accept": "*/*",
                  "Host": "integration-orasenatdpltintegration02.integration.ocp.oraclecloud.com:443",
              }
            };
            var req = http.request(options, function (res) {
              var chunks = [];
              res.on("data", function (chunk) {
                  chunks.push(chunk);
              });
              res.on("end", function () {
                  var body = Buffer.concat(chunks);
                  fs.writeFileSync(attachmentName,body.toString())
              });
            });
            req.end();
           }
          }          
EOF
    done
done
cd ..
done


#loop through connectors to pull
for connector in ${GET_CONNECTIONS}
do
  curl -u ${OIC_USERNAME}:${OIC_PASSWORD} -H “Content-Type:octet-stream” -X GET \
  ${OIC_BASE_URL}/ic/api/integration/v1/connections/$connector -v --output connector.json
  sed '5!d' connector.json > $connector.json
   
node<<EOF

        const fs = require('fs');
        const http = require("https");
        const data = require('./${connector}.json')
        var auth = 'Basic ' + Buffer.from('${OIC_USERNAME}:${OIC_PASSWORD}').toString('base64');
        delete data.adapterType.type
        var dataString=JSON.stringify(data)
        fs.writeFileSync('$connector.json',dataString)

        if(data.connectionProperties != undefined){
          if(data.connectionProperties[0].attachment != undefined){
            attachmentName = data.connectionProperties[0].attachment.attachmentName
            propertyName = data.connectionProperties[0].attachment.propertyName
            console.log("attach: " + attachmentName + "\nprop: " + propertyName)
            //Write to json to make sure it is able to be immediately re-uploaded
            
            //API call to get attachment
            var options = {
              "method": "GET",
              "hostname":"integration-orasenatdpltintegration02.integration.ocp.oraclecloud.com",
              "port": "443",
              "path": "/ic/api/integration/v1/connections/${connector}/attachments/"+propertyName,
              "headers": {
                  "Authorization": auth,
                  "Accept": "*/*",
                  "Host": "integration-orasenatdpltintegration02.integration.ocp.oraclecloud.com:443",
              }
            };
            var req = http.request(options, function (res) {
              var chunks = [];
              res.on("data", function (chunk) {
                  chunks.push(chunk);
              });
              res.on("end", function () {
                  var body = Buffer.concat(chunks);
                  fs.writeFileSync(attachmentName,body.toString())
              });
            });
            req.end();
           }
          }   
EOF
done


#Pull down relevant process Applications
for project in ${PROJECT_NAME}
  do
  curl -u ${OIC_USERNAME}:${OIC_PASSWORD} -H “Content-Type:octet-stream” -X GET https://integration-orasenatdpltintegration02.integration.ocp.oraclecloud.com:443/ic/api/process/v1/spaces/${GET_SPACEID}/projects/${GET_PROJECTID}/exp -v --output $project.exp
done

git add .
git commit -m wip
git push
