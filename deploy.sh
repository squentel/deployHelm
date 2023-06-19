# Step 1 - configure your environment
## go to Support > Api client and keys
## Create API Client and keys with these scope :
## Falcon Image Download (read)
## Sensor Download (read)
export FALCON_CLIENT_ID= && \
export FALCON_CLIENT_SECRET= && \
export FALCON_CID=&& \
export FALCON_CLOUD_REGION=eu-1 && \
export FALCON_CLOUD_API=api.eu-1.crowdstrike.com


# Step 2 - Get the registry password from API
## get OAuth2 token
FALCON_API_BEARER_TOKEN=$(curl \
--silent \
--header "Content-Type: application/x-www-form-urlencoded" \
--data "client_id=${FALCON_CLIENT_ID}&client_secret=${FALCON_CLIENT_SECRET}" \
--request POST \
--url "https://$FALCON_CLOUD_API/oauth2/token" | \
python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])"
)
##Step 3 - get your CrowdStrike's regsitry password
export FALCON_ART_PASSWORD=$(curl --silent -X GET -H "authorization: Bearer ${FALCON_API_BEARER_TOKEN}" \
https://${FALCON_CLOUD_API}/container-security/entities/image-registry-credentials/v1 | \
python3 -c "import sys, json; print(json.load(sys.stdin)['resources'][0]['token'])"
)

## Step 4 - format the username to login to crowdstrike registry
## it's based on your CID - format fc-xxxxxxxxxxxxxxxxxxxxx
export FALCON_ART_USERNAME="fc-$(echo $FALCON_CID | awk '{ print tolower($0) }' | cut -d'-' -f1)"


========== FIND LATEST SENSOR VERSION  ==========
# note it requires jq to be installed
#Step 5 - declare sensor type
export SENSORTYPE=falcon-sensor  # falcon-sensor (DaemonSet)


###Step 6 - Find the latest sensor version
export REGISTRYBEARER=$(curl -X GET -s -u "${FALCON_ART_USERNAME}:${FALCON_ART_PASSWORD}" "https://registry.crowdstrike.com/v2/token?=${FALCON_ART_USERNAME}&scope=repository:$SENSORTYPE/$FALCON_CLOUD_REGION/release/falcon-sensor:pull&service=registry.crowdstrike.com" | jq -r '.token') && \
export LATESTSENSOR=$(curl -X GET -s -H "authorization: Bearer ${REGISTRYBEARER}" "https://registry.crowdstrike.com/v2/${SENSORTYPE}/${FALCON_CLOUD_REGION}/release/falcon-sensor/tags/list" | jq -r '.tags[-1]')

####Step 7 - get sensor version
FALCON_IMAGE_REPO="registry.crowdstrike.com/${SENSORTYPE}/${FALCON_CLOUD_REGION}/release/falcon-sensor" && \
FALCON_IMAGE_TAG=$LATESTSENSOR


If you need to pull the image locally and pushing it to customer registry:
========== PULL/PUSH SENSOR IMAGE (DAEMONSET OR SIDECAR) LOCALLY  ==========
## Download the Falcon Image (DaemonSet OR Falcon Container and save it to your registry)
### Pull image from Crowdstrike registry
echo $FALCON_ART_PASSWORD | docker login -u $FALCON_ART_USERNAME --password-stdin registry.crowdstrike.com
### Get sensor for DaemonSet
docker pull $FALCON_IMAGE_REPO:$FALCON_IMAGE_TAG
### Tag the image to point to your registry
docker tag $FALCON_IMAGE_REPO:$FALCON_IMAGE_TAG YOUR_REGISTRY:YOUR_TAG
### push the image to your registry
docker push YOUR_REGISTRY:YOUR_TAG



========== HELM DEPLOYMENT
# Deploying DaemonSet with helm:
## https://artifacthub.io/packages/helm/falcon-helm/falcon-sensor
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
# if you need to build your IMAGE_PULL_TOKEN:
export PARTIALPULLTOKEN=$(echo -n "$FALCON_ART_USERNAME:$FALCON_ART_PASSWORD" | base64 -w 0) && \
export FALCON_IMAGE_PULL_TOKEN=$( echo "{\"auths\": { \"registry.crowdstrike.com\": { \"auth\": \"$PARTIALPULLTOKEN\" } } }" | base64 -w 0)

# Choose between kernel and eBPF
export SENSOR_MODE="kernel" # "bpf" or "kernel"

helm upgrade --install falcon-helm crowdstrike/falcon-sensor -n falcon-system --create-namespace \
--set falcon.cid="$FALCON_CID" \
--set falcon.tags="daemonset" \
--set node.backend="$SENSOR_MODE" \
--set node.image.repository="$FALCON_IMAGE_REPO" \
--set node.image.tag="$FALCON_IMAGE_TAG" \
--set node.image.registryConfigJSON="$FALCON_IMAGE_PULL_TOKEN"


========== Review DEPLOYMENT  =========
kubectl get pods -n falcon-system


========== K8s PROTECTION DEPLOYMENT  ==========
#vim the config.yaml:
crowdstrikeConfig:
  clientID: ""
  clientSecret: ""
  clusterName: 
  env: eu-1
  cid: 
  dockerAPIToken: 

helm repo add kpagent-helm https://registry.crowdstrike.com/kpagent-helm && helm repo update
helm upgrade --install -f config.yaml --create-namespace -n falcon-kubernetes-protection kpagent kpagent-helm/cs-k8s-protection-agent
kubectl -n falcon-kubernetes-protection get pods
