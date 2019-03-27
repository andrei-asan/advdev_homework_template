#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources

oc new-app --template=jenkins-persistent \
--param=MEMORY_LIMIT=2Gi \
--param=VOLUME_CAPACITY=4Gi \
 -n ${GUID}-jenkins

oc set resources dc jenkins --requests=cpu=1 --limits=cpu=1

# Create custom agent container image with skopeo
# TBD
oc new-build  -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\n
      USER root\nRUN yum -y install skopeo && yum clean all\n
      USER 1001' --name=jenkins-agent-appdev -n ${GUID}-jenkins

#add slave to jenkins
oc label is jenkins-agent-appdev role=jenkins-slave

oc create configmap maven-appdev \
    --from-file=PodTemplate.xml \

oc label configmap maven-appdev role=jenkins-slave

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
oc new-build https://github.com/andrei-asan/advdev_homework_template --context-dir=openshift-tasks --strategy=pipeline --name=tasks-pipeline -e GUID=${GUID}

# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done
