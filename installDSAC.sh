echo "#######installing DS#######"
export FALCON_CLIENT_ID=<YOUR_CLIENT_ID>
export FALCON_CLIENT_SECRET=<YOUR_CLIENT_SECRET>
export FALCON_CID=<YOUR_CID>
export FALCON_CLOUD_REGION=<YOUR_REGION>
export FALCON_CLOUD_API=api.<YOUR_REGION>.crowdstrike.com
export KAC_IMAGE_REPO=registry.crowdstrike.com/falcon-kac/<YOUR_REGION>/release/falcon-kac
FALCON_API_BEARER_TOKEN=$(curl \
--silent \
--header "Content-Type: application/x-www-form-urlencoded" \
--data "client_id=${FALCON_CLIENT_ID}&client_secret=${FALCON_CLIENT_SECRET}" \
--request POST \
--url "https://$FALCON_CLOUD_API/oauth2/token" | \
python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])"
)
export FALCON_ART_PASSWORD=$(curl --silent -X GET -H "authorization: Bearer ${FALCON_API_BEARER_TOKEN}" \
https://${FALCON_CLOUD_API}/container-security/entities/image-registry-credentials/v1 | \
python3 -c "import sys, json; print(json.load(sys.stdin)['resources'][0]['token'])"
)
export FALCON_ART_USERNAME="fc-$(echo $FALCON_CID | awk '{ print tolower($0) }' | cut -d'-' -f1)"
export SENSORTYPE=falcon-sensor
export REGISTRYBEARER=$(curl -X GET -s -u "${FALCON_ART_USERNAME}:${FALCON_ART_PASSWORD}" "https://registry.crowdstrike.com/v2/token?=${FALCON_ART_USERNAME}&scope=repository:$SENSORTYPE/$FALCON_CLOUD_REGION/release/falcon-sensor:pull&service=registry.crowdstrike.com" | jq -r '.token')
export LATESTSENSOR=$(curl -X GET -s -H "authorization: Bearer ${REGISTRYBEARER}" "https://registry.crowdstrike.com/v2/${SENSORTYPE}/${FALCON_CLOUD_REGION}/release/falcon-sensor/tags/list" | jq -r '.tags[-1]')
FALCON_IMAGE_REPO="registry.crowdstrike.com/${SENSORTYPE}/${FALCON_CLOUD_REGION}/release/falcon-sensor"
FALCON_IMAGE_TAG=$LATESTSENSOR
echo "#######installing HELM#######"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm --force-update
export PARTIALPULLTOKEN=$(echo -n "$FALCON_ART_USERNAME:$FALCON_ART_PASSWORD" | base64 -w 0)
export FALCON_IMAGE_PULL_TOKEN=$( echo "{\"auths\": { \"registry.crowdstrike.com\": { \"auth\": \"$PARTIALPULLTOKEN\" } } }" | base64 -w 0)
export SENSOR_MODE="kernel"
helm upgrade --install falcon-helm crowdstrike/falcon-sensor -n falcon-system --create-namespace \
--set falcon.cid="$FALCON_CID" \
--set falcon.tags="daemonset" \
--set node.backend="$SENSOR_MODE" \
--set node.image.repository="$FALCON_IMAGE_REPO" \
--set node.image.tag="$FALCON_IMAGE_TAG" \
--set node.image.registryConfigJSON="$FALCON_IMAGE_PULL_TOKEN"
echo "#######DS installed#######"

######KAC###### (see https://falcon.eu-1.crowdstrike.com/documentation/366/get-sensor-image#option-1-pull-the-falcon-sensor-image-using-a-bash-script)
echo "#######installing KAC#######"
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
helm repo update
helm repo list
export FALCON_CONTAINER_REGISTRY=registry.crowdstrike.com
export SENSORTYPE=falcon-kac
export FALCON_CS_API_TOKEN=$(curl \
--silent \
--header "Content-Type: application/x-www-form-urlencoded" \
--data "client_id=${FALCON_CLIENT_ID}&client_secret=${FALCON_CLIENT_SECRET}" \
--request POST \
--url "https://$FALCON_CLOUD_API/oauth2/token" | \
python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])"
)
export FALCON_ART_USERNAME="fc-$(echo ${FALCON_CID} | awk '{ print tolower($0) }' | cut -d'-' -f1)"
export FALCON_ART_PASSWORD=$(curl -X GET -H "authorization: Bearer ${FALCON_CS_API_TOKEN}" https://${FALCON_CLOUD_API}/container-security/entities/image-registry-credentials/v1 | jq -cr '.resources[].token | values')
export REGISTRY_BEARER=$(curl -X GET -s -u "${FALCON_ART_USERNAME}:${FALCON_ART_PASSWORD}" "https://${FALCON_CONTAINER_REGISTRY}/v2/token?=fc-${FALCON_CID}&scope=repository:falcon-sensor/${FALCON_REGION}/release/falcon-sensor:pull&service=${FALCON_CONTAINER_REGISTRY}" | jq -r '.token')
export FALCON_SENSOR_IMAGE_REPO="${FALCON_CONTAINER_REGISTRY}/${SENSORTYPE}/${FALCON_CLOUD_REGION}/release/$([ $SENSORTYPE = "falcon-container" ] && echo "falcon-sensor" || echo "$SENSORTYPE")"
export FALCON_SENSOR_IMAGE_TAG=$(curl -X GET -s -H "authorization: Bearer ${REGISTRY_BEARER}" "https://${FALCON_CONTAINER_REGISTRY}/v2/${SENSORTYPE}/${FALCON_CLOUD_REGION}/release/$SENSORTYPE/tags/list" | jq -r '.tags[-1]')
export PARTIALPULLTOKEN=$(echo -n "$FALCON_ART_USERNAME:$FALCON_ART_PASSWORD" | base64 -w 0)
export FALCON_IMAGE_PULL_TOKEN=$( echo "{\"auths\": { \"registry.crowdstrike.com\": { \"auth\": \"$PARTIALPULLTOKEN\" } } }" | base64 -w 0)
helm install falcon-kac crowdstrike/falcon-kac \
  -n falcon-kac --create-namespace \
  --set falcon.cid=$FALCON_CID \
  --set image.repository=$KAC_IMAGE_REPO \
  --set image.tag=$FALCON_SENSOR_IMAGE_TAG  \
  --set image.registryConfigJSON="$FALCON_IMAGE_PULL_TOKEN"
  echo "#######KAC installed#######"
