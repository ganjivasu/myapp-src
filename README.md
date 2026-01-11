**Check below softwares are available in your machine
**

aws --version
kubectl version --client
eksctl version
docker --version


**Create Cluster
**

eksctl create cluster \
  --name myapp-cluster \
  --region us-east-1 \
  --nodes 2 \
  --node-type t3.medium

**Configure kubectl & verify
**

aws eks update-kubeconfig --name myapp-cluster --region us-east-1

kubectl get nodes

**Create ECR Repository
**

aws ecr create-repository --repository-name myapp

**Login to ECR**

aws ecr get-login-password --region us-east-1 \
| docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

**Repo Structure
**

myapp-src/
├── app.py
├── requirements.txt
├── Dockerfile
└── .github/workflows/ci.yaml

**CD Repo Structure
**

myapp-gitops/
└── myapp/
    ├── dev/
    ├── pt/
    ├── qa/
    └── prod/


**Create namespaces
**

kubectl create ns dev
kubectl create ns pt
kubectl create ns qa
kubectl create ns prod


**Install argocd on EKS
**

kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


**Expose argocd
**

kubectl port-forward svc/argocd-server -n argocd 8080:443

**Get argocd admin password
**

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

**Create argocd application
**

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ganjivasu/myapp-gitops
    targetRevision: main
    path: myapp/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true


**apply**

kubectl apply -f myapp-dev.yaml


**AWS_ROLE (MOST IMPORTANT)**

This is an IAM Role that GitHub Actions will assume to push images to ECR.

Example value:
arn:aws:iam::123456789012:role/github-actions-ecr-role

🧩 STEP-BY-STEP: CREATE THE AWS_ROLE (BEGINNER FRIENDLY)
🔹 Step A — Create IAM Role

Go to AWS Console → IAM → Roles → Create Role

Trusted entity:

Select: Web identity

Identity provider: GitHub

Audience: sts.amazonaws.com


**Add Identity Provider
**

Provider type: OpenID Connect
Provider URL: https://token.actions.githubusercontent.com
Audience: sts.amazonaws.com
Click Next
Attach permissions: AmazonEC2ContainerRegistryPowerUser
Click Next
Role Name: github-actions-ecr-role


Clear ECR Repository old Images using below command

 aws ecr put-lifecycle-policy \
  --repository-name myapp \
  --lifecycle-policy-text file://lifecycle.json

#Install Argo Rollouts (one-time)
kubectl create namespace argo-rollouts

kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

#verify
kubectl get pods -n argo-rollouts

#Check node CIDR allocation
kubectl get nodes -o json | jq '.items[].spec.podCIDR'


Build
 └── Immutable Image
      └── Promotion Artifact
           ├── Metadata
           ├── Checksum
           └── Audit Trail
                ↓
        GitOps Repo Update
                ↓
        ArgoCD Sync
                ↓
        Canary Rollout
                ↓
        Auto Analysis
                ↓
        Promote OR Rollback




🔍 How to check this LIVE on your cluster
1️⃣ Check max pods on node
kubectl describe node <node-name> | grep -i pods

2️⃣ Check instance type
kubectl get nodes -o wide

🔧 How to enable Prefix Delegation
kubectl set env daemonset aws-node \
  -n kube-system \
  ENABLE_PREFIX_DELEGATION=true \
  WARM_PREFIX_TARGET=1


Verify:

kubectl describe node <node> | grep -i prefix

#Prometheus installation
kubectl config current-context

#Add Helm Repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

#install prometheus
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

#Run this before enabling canary metrics:

kubectl port-forward \
  svc/prometheus-kube-prometheus-prometheus \
  -n monitoring \
  9090:9090


#Then open:
http://localhost:9090


#Run:
http_requests_total

#verify installation
kubectl get pods -n monitoring


You should see:

prometheus-kube-prometheus-stack-prometheus-0
prometheus-kube-prometheus-stack-grafana
prometheus-kube-prometheus-stack-operator

#verify exact service name
kubectl get svc -n monitoring

#show all resources under overlays/dev-pt-qa-prod
kubectl kustomize myapp/overlays/prod | grep -E "kind: (Rollout|Service|AnalysisTemplate)"


🧪 How to verify the service name yourself

Run this:

kubectl get svc -n monitoring | grep prometheus


You’ll see something like:

prometheus-kube-prometheus-prometheus   ClusterIP   ...

#Confirm prod rollout is healthy
kubectl get rollout myapp -n prod
kubectl get pods -n prod
kubectl get analysisrun -n prod


Expected:

Rollout phase: Healthy
Pods: Running
AnalysisRun: Successful


#Verify traffic shifting actually works
kubectl argo rollouts get rollout myapp -n prod

#You should see:

Step-by-step weight progression (10 → 30 → 60 → 100)

Analysis runs at each step

# If you don’t have the plugin:

brew install argoproj/tap/kubectl-argo-rollouts


#Then promote manually:
kubectl argo rollouts promote myapp -n prod

#Promote rollback:
kubectl argo rollouts abort myapp -n prod
kubectl argo rollouts undo myapp -n prod


#Add this annotation to Rollout:

metadata:
  annotations:
    rollouts.argoproj.io/managed-by: argocd


#Then open:
kubectl argo rollouts dashboard


#You’ll see:
Canary steps
Metrics graph
Live promotion buttons


#Final validation checklist (run in order)
kubectl kustomize overlays/prod | grep image:
kubectl apply -n prod --dry-run=server -f <(kubectl kustomize overlays/prod)
kubectl argo rollouts get rollout myapp -n prod
kubectl get analysisrun -n prod


#Validation (run once per env)
kubectl kustomize overlays/dev | grep AnalysisTemplate
kubectl kustomize overlays/qa | grep AnalysisTemplate
kubectl get analysistemplate -A


#install k6 operator
kubectl create namespace k6
kubectl apply -f https://github.com/grafana/k6-operator/releases/latest/download/k6-operator.yaml

#verify
kubectl get pods -n k6


#Final verification checklist (DO THESE)
kubectl get analysistemplates -n prod
kubectl get analysisrun -n prod
kubectl describe analysisrun -n prod
kubectl get k6 -A


#Grafana queries:

k6_http_req_failed
k6_http_req_duration
http_requests_total

NAME: prometheus
LAST DEPLOYED: Thu Jan  1 23:19:26 2026
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace monitoring get pods -l "release=prometheus"

Get Grafana 'admin' user password by running:

  kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

Access Grafana local instance:

  export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus" -oname)
  kubectl --namespace monitoring port-forward $POD_NAME 3000

Get your grafana admin user password by running:

  kubectl get secret --namespace monitoring -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" | base64 --decode ; echo


Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.

#How to Run k6 During Canary
kubectl apply -f manifests/configmap.yaml
kubectl apply -f manifests/testrun.yaml


kubectl apply -f configmap-k6-test.yaml
kubectl apply -f testrun.yaml

kubectl get testruns -n k6
kubectl logs -n k6 -l app=k6

#Create Slack webhook secret
it is in the notepad - copy it and run

#Grafana dashboard configmap apply command
kubectl apply -f monitoring/grafana-myapp-canary.yaml

#Apply argocd root app 
kubectl apply -f argocd/root-app.yaml


1️⃣ Install LitmusChaos (one-time)
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator.yaml

Verify:
kubectl get pods -n litmus



#Delete Cluster
eksctl delete cluster --name myapp-cluster --region us-east-1 --wait