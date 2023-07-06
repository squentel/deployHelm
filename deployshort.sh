export FALCON_CLIENT_ID=<YOUR_CLIENT_ID> && \
export FALCON_CLIENT_SECRET=<YOUR_CLIENT_SECRET> && \
export FALCON_CID=<YOUR_CID> && \
export FALCON_CLOUD_REGION=eu-1 && \
export FALCON_CLOUD_API=api.eu-1.crowdstrike.com
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
export SENSORTYPE=falcon-sensor  # falcon-sensor (DaemonSet)
export REGISTRYBEARER=$(curl -X GET -s -u "${FALCON_ART_USERNAME}:${FALCON_ART_PASSWORD}" "https://registry.crowdstrike.com/v2/token?=${FALCON_ART_USERNAME}&scope=repository:$SENSORTYPE/$FALCON_CLOUD_REGION/release/falcon-sensor:pull&service=registry.crowdstrike.com" | jq -r '.token') && \
export LATESTSENSOR=$(curl -X GET -s -H "authorization: Bearer ${REGISTRYBEARER}" "https://registry.crowdstrike.com/v2/${SENSORTYPE}/${FALCON_CLOUD_REGION}/release/falcon-sensor/tags/list" | jq -r '.tags[-1]')
FALCON_IMAGE_REPO="registry.crowdstrike.com/${SENSORTYPE}/${FALCON_CLOUD_REGION}/release/falcon-sensor" && \
FALCON_IMAGE_TAG=$LATESTSENSOR
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm --force-update
export PARTIALPULLTOKEN=$(echo -n "$FALCON_ART_USERNAME:$FALCON_ART_PASSWORD" | base64 -w 0) && \
export FALCON_IMAGE_PULL_TOKEN=$( echo "{\"auths\": { \"registry.crowdstrike.com\": { \"auth\": \"$PARTIALPULLTOKEN\" } } }" | base64 -w 0)
export SENSOR_MODE="kernel" 
helm upgrade --install falcon-helm crowdstrike/falcon-sensor -n falcon-system --create-namespace \
--set falcon.cid="$FALCON_CID" \
--set falcon.tags="daemonset" \
--set node.backend="$SENSOR_MODE" \
--set node.image.repository="$FALCON_IMAGE_REPO" \
--set node.image.tag="$FALCON_IMAGE_TAG" \
--set node.image.registryConfigJSON="$FALCON_IMAGE_PULL_TOKEN"
