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
    image: docker:24-dind
    command: ['sleep']
    args: ['999999']
    volumeMounts:
      - name: docker-sock
        mountPath: /var/run/docker.sock

  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["tail"]
    args: ["-f", "/dev/null"]
    volumeMounts:
      - name: workspace-volume
        mountPath: /home/jenkins/agent
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"

  volumes:
    - name: docker-sock
      hostPath:
        path: /var/run/docker.sock
    - name: workspace-volume
      emptyDir: {}
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
        IMAGE_TAG = "${env.GIT_COMMIT ? env.GIT_COMMIT.substring(0,7) : 'latest'}"
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

        stage('Deploy to Kubernetes') {
            steps {
                container('docker') {
                    sh '''
                    # Instala kubectl temporariamente
                    apk add --no-cache curl
                    curl -LO https://dl.k8s.io/release/stable.txt
                    curl -LO "https://dl.k8s.io/release/$(cat stable.txt)/bin/linux/amd64/kubectl"
                    chmod +x kubectl
                    mv kubectl /usr/local/bin/

                    # Atualiza deployment
                    kubectl set image deployment/${IMAGE_NAME} ${IMAGE_NAME}=${IMAGE_NAME}:${IMAGE_TAG} -n ${K8S_NAMESPACE} || \
                    kubectl set image deployment/${IMAGE_NAME} ${IMAGE_NAME}=${IMAGE_NAME}:latest -n ${K8S_NAMESPACE}

                    # Espera rollout
                    kubectl rollout status deployment/${IMAGE_NAME} -n ${K8S_NAMESPACE} --timeout=300s
                    kubectl get pods -n ${K8S_NAMESPACE} -o wide
                    '''
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
        failure {
            echo "❌ Pipeline falhou!"
        }
    }
}
