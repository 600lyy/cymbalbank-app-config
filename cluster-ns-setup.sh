#!/bin/bash 


########### VARIABLES  ##################################
if [[ -z "$PROJECT_ID" ]]; then
    echo "Must provide PROJECT_ID in environment" 1>&2
    exit 1
fi

# Cymbal app 
export KSA_NAME="cymbal-ksa"
export GSA_NAME="cymbal-gsa"

############################################################


setup_namespaces () {
    CLUSTER_NAME=$1 
    CLUSTER_ZONE=$2 
    echo "☸️ Setting up cluster: $CLUSTER_NAME, zone: $CLUSTER_ZONE" 
    gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${CLUSTER_ZONE} --project ${PROJECT_ID} 
    kubectl ctx ${CLUSTER_NAME}=. 

    echo "💡 Creating a Kubernetes Service Account (KSA) for each CymbalBank namespace..."
    declare -a NAMESPACES=("balancereader" "transactionhistory" "ledgerwriter" "contacts" "userservice" "frontend" "loadgenerator")

    for ns in "${NAMESPACES[@]}"
    do
        echo "****** 🔁 Setting up namespace: ${ns} ********"
        # boostrap namespace 
        kubectl create namespace $ns 

        # boostrap ksa 
        kubectl create serviceaccount --namespace $ns $KSA_NAME

        # connect KSA to GSA (many KSAs to 1 GSA)
        echo "☁️ Allowing KSA: ${KSA_NAME} to act as GSA: ${GSA_NAME}"
        kubectl annotate serviceaccount \
            --namespace $ns \
            $KSA_NAME \
            iam.gke.io/gcp-service-account=$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com
        
        gcloud iam service-accounts add-iam-policy-binding \
            --role roles/iam.workloadIdentityUser \
            --member "serviceAccount:${PROJECT_ID}.svc.id.goog[$ns/$KSA_NAME]" \
            $GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com

    done 
    echo "⭐️ Done with cluster: ${CLUSTER_NAME}"
    }

# kubeconfig for admin cluster 
gcloud config set project ${PROJECT_ID}


# Set up clusters for the CymbalBank app
setup_namespaces "cymbal-prod" "europe-north1-a"

echo "✅ GKE Cluster Namespaces Setup Complete."