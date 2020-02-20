#V1.0 - Last Updated 20/02/2020 by Pravin Thakre

#Params to add to build: 
#OIC_USERNAME
#OICPASSWORD
#OIC_SOURCE_ENV

chmod 755 CONFIGS/env-${OIC_TARGET_ENV}
source ./CONFIGS/env-${OIC_TARGET_ENV}

#push new integrations
for integration in ${CREATE_INTEGRATIONS}
do
echo increate
     curl -u ${OIC_USERNAME}:${OIC_PASSWORD} -H “Content-Type:multipart/form-data” -X POST \
    -F 'file=@'$integration.iar';type=application/octet-stream' ${OIC_BASE_URL}'/ic/api/integration/v1/integrations/archive' -v
done

#Deactivate Integrations
#push updated integrations
for ((integration=0; integration<${#UPDATE_INTEGRATIONS[@]}; integration=integration+2))
do
  echo inupdate
    curl -X POST \
  ${OIC_BASE_URL}/ic/api/integration/v1/integrations/${UPDATE_INTEGRATIONS[$integration]}\|${UPDATE_INTEGRATIONS[$integration+1]} \
  -u ${OIC_USERNAME}:${OIC_PASSWORD} \
  -H 'Content-Type: application/json' \
  -H 'X-HTTP-Method-Override: PATCH' \
  -H 'cache-control: no-cache' \
  -H 'status: CONFIGURED' \
  -d '{
  "status":"CONFIGURED"    
  }'
    curl -u ${OIC_USERNAME}:${OIC_PASSWORD} -H “Content-Type:multipart/form-data” -X PUT \
    -F 'file=@'${UPDATE_INTEGRATIONS[$integration]}.iar';type=application/octet-stream' ${OIC_BASE_URL}'/ic/api/integration/v1/integrations/archive' -v  
done

for connection in ${UPDATE_CONNECTIONS}
do
  curl -X POST \
  ${OIC_BASE_URL}/ic/api/integration/v1/connections/$connection \
  -u ${OIC_USERNAME}:${OIC_PASSWORD} \
  -H 'Content-Type: application/json' \
  -H 'X-HTTP-Method-Override: PATCH' \
  -d '@'$connection'.json'
  
  
  curl -X POST \
  ${OIC_BASE_URL}/ic/api/integration/v1/connections/$connection/test \
  -u ${OIC_USERNAME}:${OIC_PASSWORD} \
  -H 'Content-Type: application/json' 
  
done

echo activate integrations
#activate UPDATED integrations
for ((integration=0; integration<${#UPDATE_INTEGRATIONS[@]}; integration=integration+2))
do
echo inactivateupdate
  curl -X POST \
  ${OIC_BASE_URL}'/ic/api/integration/v1/integrations/'${UPDATE_INTEGRATIONS[$integration]}\|${UPDATE_INTEGRATIONS[$integration+1]} \
  -u ${OIC_USERNAME}:${OIC_PASSWORD}\
  -H 'Content-Type: application/json' \
  -H 'X-HTTP-Method-Override: PATCH' \
  -d '{"status":"ACTIVATED"}' -v
done

#activate CREATED integrations
for ((integration=0; integration<${#CREATE_INTEGRATIONS[@]}; integration=integration+2))
do
curl -X POST \
  ${OIC_BASE_URL}'/ic/api/integration/v1/integrations/'${CREATE_INTEGRATIONS[$integration]}\|${CREATE_INTEGRATIONS[$integration+1]} \
  -u ${OIC_USERNAME}:${OIC_PASSWORD}\
  -H 'Content-Type: application/json' \
  -H 'X-HTTP-Method-Override: PATCH' \
  -d '{"status":"ACTIVATED"}' -v
done

for package in ${UPDATE_PACKAGE}
do

  #Enter Directory For Package
  cd ${package}_package

  #Import the Par file for package
  curl -u ${OIC_USERNAME}:${OIC_PASSWORD} -H “Content-Type:multipart/form-data” -X POST \
  -F 'file=@'${package}.par';type=application/octet-stream' ${OIC_BASE_URL}'/ic/api/integration/v1/packages/archive' -v

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
        echo "connector: ${connector}"
        
        curl -X POST \
        ${OIC_BASE_URL}/ic/api/integration/v1/connections/${connector} \
        -u ${OIC_USERNAME}:${OIC_PASSWORD} \
        -H 'Content-Type: application/json' \
        -H 'X-HTTP-Method-Override: PATCH' \
        -d '@'${connector}'.json'
  
  
        curl -X POST \
        ${OIC_BASE_URL}/ic/api/integration/v1/connections/${connector}/test \
        -u ${OIC_USERNAME}:${OIC_PASSWORD} \
        -H 'Content-Type: application/json' 
    done
    
    curl -X POST \
  ${OIC_BASE_URL}'/ic/api/integration/v1/integrations/'${integration} \
  -u ${OIC_USERNAME}:${OIC_PASSWORD}\
  -H 'Content-Type: application/json' \
  -H 'X-HTTP-Method-Override: PATCH' \
  -d '{"status":"ACTIVATED"}' -v
  done
  cd ..
done

for project in ${POST_PROJECT_NAME}
do 
    curl -u ${OIC_USERNAME}:${OIC_PASSWORD}\
    -X POST --header 'Content-Type: multipart/form-data'\
    --header 'Accept: application/json' -F 'projectName=MyProject2'\
    -F 'exp=@'${POST_PROJECT_NAME}';type=application/octet-stream'\
    ${OIC_BASE_URL}/ic/api/process/v1/spaces/${POST_SPACEID}/projects -v
done
