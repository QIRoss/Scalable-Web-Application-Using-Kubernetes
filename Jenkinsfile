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
    image: bitnami/kubectl:1.33
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

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    sh '''
                    echo "🚀 Updating deployment ${IMAGE_NAME} with new image..."
                    kubectl set image deployment/${IMAGE_NAME} ${IMAGE_NAME}=${IMAGE_NAME}:${IMAGE_TAG} -n ${K8S_NAMESPACE} || \
                    kubectl set image deployment/${IMAGE_NAME} ${IMAGE_NAME}=${IMAGE_NAME}:latest -n ${K8S_NAMESPACE}
                    
                    echo "⏳ Waiting for rollout to finish..."
                    kubectl rollout status deployment/${IMAGE_NAME} -n ${K8S_NAMESPACE} --timeout=300s

                    echo "📊 Current pods:"
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
    }
}
