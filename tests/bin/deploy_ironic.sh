function general_config {
#
#  Passed parameters: $1 - IP, $2 - base_distro,
#                     $3 - tunnel_interface
#
    common_workflow_config $1 $2 $3
}

function iscsi_config {
    common_iscsi_config
}

function deploy_ironic {
#
#  Passed parameters: $1 - IP, $2 - base_distro,
#                     $3 - tunnel_interface, $4 - branch,
#                     $5 - config
#
IP="$1"
tunnel_interface="$3"
base_distro="$2"
branch="$4"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"

. "$DIR/tests/bin/common_workflow_config.sh"
if [ "x$branch" == "x3" ]; then
. "$DIR/tests/bin/common_iscsi_config_v3.sh"
else
. "$DIR/tests/bin/common_iscsi_config.sh"
fi

general_config $IP $base_distro $tunnel_interface > /tmp/general_config.yaml
iscsi_config > /tmp/iscsi_config.yaml

helm install kolla/ironic-api-svc --version $VERSION \
    --namespace kolla --name ironic-api-svc \
    --values /tmp/general_config.yaml --values /tmp/iscsi_config.yaml

helm install kolla/ironic-create-keystone-service-job --version $VERSION \
    --namespace kolla --name ironic-create-keystone-service \
    --values /tmp/general_config.yaml --values /tmp/iscsi_config.yaml

helm install kolla/ironic-create-keystone-user-job --version $VERSION \
    --namespace kolla --name ironic-create-keystone-user \
    --values /tmp/general_config.yaml --values /tmp/iscsi_config.yaml

$DIR/tools/wait_for_pods.sh kolla

helm delete --purge ironic-create-keystone-user
helm delete --purge ironic-create-keystone-service

helm install kolla/ironic-api-create-db-job --version $VERSION \
    --namespace kolla --name ironic-api-create-db \
    --values /tmp/general_config.yaml --values /tmp/iscsi_config.yaml

$DIR/tools/wait_for_pods.sh kolla

helm install kolla/ironic-api-manage-db-job --version $VERSION \
    --namespace kolla --name ironic-api-manage-db \
    --values /tmp/general_config.yaml --values /tmp/iscsi_config.yaml

helm install kolla/ironic-api-create-keystone-endpoint-internal-job --version $VERSION \
    --namespace kolla --name ironic-api-create-keystone-endpoint-internal \
    --values /tmp/general_config.yaml --values /tmp/iscsi_config.yaml

helm install kolla/ironic-api-create-keystone-endpoint-admin-job --version $VERSION \
    --namespace kolla --name ironic-api-create-keystone-endpoint-admin \
    --values /tmp/general_config.yaml --values /tmp/iscsi_config.yaml

helm install kolla/ironic-api-create-keystone-endpoint-public-job --version $VERSION \
    --namespace kolla --name ironic-api-create-keystone-endpoint-public \
    --values /tmp/general_config.yaml --values /tmp/iscsi_config.yaml

$DIR/tools/wait_for_pods.sh kolla

helm install kolla/ironic-api-deployment --version $VERSION \
    --namespace kolla --name ironic-api-deployment \
    --values /tmp/general_config.yaml --values /tmp/iscsi_config.yaml

$DIR/tools/wait_for_pods.sh kolla

helm install kolla/ironic-conductor-daemonset --version $VERSION \
    --namespace kolla --name ironic-conductor-daemonset \
    --values /tmp/general_config.yaml --values /tmp/iscsi_config.yaml

helm install kolla/nova-compute-ironic-daemonset --version $VERSION \
    --namespace kolla --name nova-compute-ironic-daemonset \
    --values /tmp/general_config.yaml --values /tmp/iscsi_config.yaml

$DIR/tools/pull_containers.sh kolla
$DIR/tools/wait_for_pods.sh kolla
}
