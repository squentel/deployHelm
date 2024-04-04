###### DOWNLOAD FALCON CONTAINER SENSOR PULL SCRIPT
curl -sSL -o falcon-container-sensor-pull.sh "https://raw.githubusercontent.com/CrowdStrike/falcon-scripts/main/bash/containers/falcon-container-sensor-pull/falcon-container-sensor-pull.sh"
chmod +x falcon-container-sensor-pull.sh

###### EXPORT FALCON API CREDENTIALS
export FALCON_CLIENT_ID=YOUR_CLIENT_ID
export FALCON_CLIENT_SECRET=YOUR_CLIENT_SECRET



###### DEPLOY DAEMONSET
###SET HELM PARAMETERS
export FALCON_CID=$( ./falcon-container-sensor-pull.sh -t falcon-sensor --get-cid )
export FALCON_IMAGE_FULL_PATH=$( ./falcon-container-sensor-pull.sh -t falcon-sensor --get-image-path )
export FALCON_IMAGE_REPO=$( echo $FALCON_IMAGE_FULL_PATH | cut -d':' -f 1 )
export FALCON_IMAGE_TAG=$( echo $FALCON_IMAGE_FULL_PATH | cut -d':' -f 2 )
export FALCON_IMAGE_PULL_TOKEN=$( ./falcon-container-sensor-pull.sh -t falcon-sensor --get-pull-token )

### HELM INSTALL
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm --force-update
helm upgrade --install falcon-sensor crowdstrike/falcon-sensor -n falcon-system --create-namespace \
--set falcon.cid="$FALCON_CID" \
--set falcon.tags="daemonset\,pov" \
--set node.image.repository="$FALCON_IMAGE_REPO" \
--set node.image.tag="$FALCON_IMAGE_TAG" \
--set node.image.registryConfigJSON="$FALCON_IMAGE_PULL_TOKEN"



###### DEPLOY Admission Controller
###SET HELM PARAMETERS
export FALCON_CID=$( ./falcon-container-sensor-pull.sh -t falcon-kac --get-cid )
export FALCON_KAC_IMAGE_FULL_PATH=$( ./falcon-container-sensor-pull.sh -t falcon-kac --get-image-path )
export FALCON_KAC_IMAGE_REPO=$( echo $FALCON_KAC_IMAGE_FULL_PATH | cut -d':' -f 1 )
export FALCON_KAC_IMAGE_TAG=$( echo $FALCON_KAC_IMAGE_FULL_PATH | cut -d':' -f 2 )
export FALCON_IMAGE_PULL_TOKEN=$( ./falcon-container-sensor-pull.sh -t falcon-kac --get-pull-token )

### HELM INSTALL
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm --force-update
helm upgrade --install falcon-kac crowdstrike/falcon-kac -n falcon-kac --create-namespace \
--set falcon.cid="$FALCON_CID" \
--set falcon.tags="kac\,pov" \
--set image.repository="$FALCON_KAC_IMAGE_REPO" \
--set image.tag="$FALCON_KAC_IMAGE_TAG" \
--set image.registryConfigJSON="$FALCON_IMAGE_PULL_TOKEN"



  
