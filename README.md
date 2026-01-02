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

#Delete Cluster
eksctl delete cluster --name myapp-cluster --region us-east-1 --wait


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
  svc/prometheus-kube-prometheus-stack-prometheus \
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

prometheus-kube-prometheus-stack-prometheus   ClusterIP   ...