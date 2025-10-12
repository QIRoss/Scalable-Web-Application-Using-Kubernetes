pipeline {
    agent {
        kubernetes {
            cloud 'minikube-local'
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  namespace: hextris
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    args: ['$(JENKINS_SECRET)', '$(JENKINS_NAME)']

  - name: docker
    image: docker:latest
    command: ['sleep']
    args: ['999999']
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock

  - name: kubectl
    image: bitnami/kubectl:latest
    command: ['sleep']
    args: ['999999']

  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
        }
    }
    
    options {
        disableConcurrentBuilds()
        timeout(time: 15, unit: 'MINUTES')
    }
    
    triggers {
        pollSCM('H/2 * * * *')
    }
    
    environment {
        IMAGE_NAME = "hextris"
        IMAGE_TAG = "${env.GIT_COMMIT ? env.GIT_COMMIT.substring(0, 7) : 'latest'}"
        K8S_NAMESPACE = "hextris"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "📦 Repository: ${env.GIT_URL}"
            }
        }
        
        stage('Build Image') {
            steps {
                container('docker') {
                    sh """
                    echo "🏗️ Building Docker image..."
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                    """
                }
            }
        }
        
        stage('Load to Minikube') {
            steps {
                container('docker') {
                    sh """
                    echo "🎯 Loading image to Minikube..."
                    minikube image load ${IMAGE_NAME}:${IMAGE_TAG}
                    minikube image load ${IMAGE_NAME}:latest
                    """
                }
            }
        }
        
        stage('Deploy') {
            steps {
                container('kubectl') {
                    sh """
                    echo "🚀 Deploying application..."
                    helm upgrade --install hextris ./helm/hextris/ \
                      --namespace ${K8S_NAMESPACE} \
                      --set image.repository=${IMAGE_NAME} \
                      --set image.tag=latest \
                      --wait --timeout 300s
                    
                    echo "📊 Deployment status:"
                    kubectl get pods,svc -n ${K8S_NAMESPACE}
                    """
                }
            }
        }
    }
    
    post {
        always {
            echo "🎯 Pipeline completed - Build #${BUILD_NUMBER}"
            container('kubectl') {
                sh "kubectl get pods -n ${K8S_NAMESPACE}"
            }
        }
        success {
            echo "🎉 Pipeline executado com sucesso!"
            script {
                currentBuild.description = "✅ Success - ${IMAGE_TAG}"
            }
        }
    }
}