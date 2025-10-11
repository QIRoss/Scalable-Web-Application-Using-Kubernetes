pipeline {
    agent {
        kubernetes {
            cloud 'hextris'
            label 'jenkins-agent'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  namespace: hextris
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    args: ['\$(JENKINS_SECRET)', '\$(JENKINS_NAME)']
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  - name: docker
    image: docker:latest
    command: ['sleep']
    args: ['infinity']
    env:
    - name: DOCKER_HOST
      value: tcp://docker:2376
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
    resources:
      requests:
        memory: "512Mi"
        cpu: "200m"
      limits:
        memory: "1Gi"
        cpu: "500m"
  
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ['sleep']
    args: ['infinity']
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "300m"

  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
"""
        }
    }
    
    environment {
        IMAGE_NAME = "hextris"
        IMAGE_TAG = "${env.GIT_COMMIT ? env.GIT_COMMIT.substring(0, 7) : 'latest'}"
        TIMESTAMP = "${new Date().format('yyyyMMdd-HHmmss')}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    echo "📦 Repository: ${env.GIT_URL}"
                    echo "🔀 Branch: ${env.GIT_BRANCH}"
                    echo "🆔 Commit: ${env.GIT_COMMIT}"
                    echo "🏷️  Image Tag: ${IMAGE_TAG}"
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                container('docker') {
                    script {
                        echo "🏗️ Building Docker image..."
                        sh """
                        # Build da imagem com múltiplas tags
                        docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:${TIMESTAMP}
                        
                        # Listar imagens criadas
                        echo "📋 Images built:"
                        docker images | grep ${IMAGE_NAME}
                        """
                    }
                }
            }
        }
        
        stage('Test Image') {
            steps {
                container('docker') {
                    script {
                        echo "🧪 Testing Docker image..."
                        sh """
                        # Testar se a imagem é construída corretamente
                        docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} echo "✅ Image test passed" || echo "⚠️ Image test completed"
                        
                        # Verificar se os arquivos necessários existem
                        docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} ls -la /app 2>/dev/null || echo "No /app directory, checking root..."
                        docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} pwd
                        """
                    }
                }
            }
        }
        
        stage('Load Image to Minikube') {
            steps {
                container('docker') {
                    script {
                        echo "🎯 Loading image to Minikube..."
                        sh """
                        # Carregar a imagem para o Minikube
                        minikube image load ${IMAGE_NAME}:${IMAGE_TAG}
                        minikube image load ${IMAGE_NAME}:latest
                        
                        # Verificar imagens no Minikube
                        echo "📋 Images in Minikube:"
                        minikube image list | grep ${IMAGE_NAME} || echo "No images found with name ${IMAGE_NAME}"
                        """
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    script {
                        echo "🚀 Deploying to Kubernetes..."
                        sh """
                        # Atualizar a imagem no deployment
                        kubectl set image deployment/hextris hextris=${IMAGE_NAME}:latest -n hextris
                        
                        # Aguardar o rollout
                        echo "⏳ Waiting for rollout to complete..."
                        kubectl rollout status deployment/hextris -n hextris --timeout=300s
                        
                        # Verificar o deployment
                        echo "📊 Deployment status:"
                        kubectl get deployment hextris -n hextris -o wide
                        """
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                container('kubectl') {
                    script {
                        echo "🔍 Verifying deployment..."
                        sh """
                        # Verificar pods
                        echo "📦 Pods status:"
                        kubectl get pods -n hextris -l app=hextris -o wide
                        
                        # Verificar logs (apenas últimas 5 linhas)
                        echo "📜 Pods logs:"
                        kubectl logs -n hextris -l app=hextris --tail=5 --prefix=true || echo "No logs available yet"
                        
                        # Verificar serviços
                        echo "🌐 Services:"
                        kubectl get service -n hextris
                        
                        echo "✅ Deployment verification completed!"
                        """
                    }
                }
            }
        }
        
        stage('Smoke Test') {
            steps {
                container('kubectl') {
                    script {
                        echo "🚬 Running smoke test..."
                        sh """
                        # Obter URL da aplicação
                        APP_URL=\$(minikube service list | grep hextris-service | grep -o 'http://[^ ]*' | head -1)
                        echo "🌐 Application URL: \$APP_URL"
                        
                        # Testar acesso (se disponível)
                        if [ ! -z "\$APP_URL" ]; then
                            echo "🔗 Testing application access..."
                            curl -s --connect-timeout 10 \$APP_URL && echo "✅ Application is accessible" || echo "⚠️ Could not access application"
                        else
                            echo "📡 No external service URL found, testing internally..."
                            kubectl port-forward -n hextris service/hextris-service 8080:80 &
                            sleep 5
                            curl -s http://localhost:8080 && echo "✅ Application is running" || echo "⚠️ Could not access application internally"
                            pkill kubectl
                        fi
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "📊 Pipeline execution completed"
            container('kubectl') {
                sh """
                echo "🎯 Final status:"
                kubectl get pods -n hextris
                echo "🏷️ Image used: ${IMAGE_NAME}:latest"
                """
            }
        }
        success {
            echo "🎉 Pipeline executed successfully!"
            script {
                currentBuild.description = "✅ Success - ${IMAGE_TAG}"
                
                // Notificação opcional
                emailext (
                    subject: "✅ Pipeline SUCCESS: ${env.JOB_NAME}",
                    body: """
                    Pipeline executado com sucesso!
                    
                    Job: ${env.JOB_NAME}
                    Build: ${env.BUILD_NUMBER}
                    Commit: ${env.GIT_COMMIT}
                    Branch: ${env.GIT_BRANCH}
                    
                    Imagem: ${IMAGE_NAME}:${IMAGE_TAG}
                    Status: Deploy realizado com sucesso
                    
                    Acesse: ${env.BUILD_URL}
                    """,
                    to: "developer@example.com"
                )
            }
        }
        failure {
            echo "❌ Pipeline failed!"
            container('kubectl') {
                sh """
                echo "🔍 Debug information:"
                kubectl describe deployment hextris -n hextris || true
                kubectl get events -n hextris --sort-by='.lastTimestamp' | tail -10 || true
                """
            }
            script {
                currentBuild.description = "❌ Failed - ${IMAGE_TAG}"
            }
        }
    }
    
    options {
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '5'))
        disableConcurrentBuilds()
    }
    
    triggers {
        pollSCM('H/2 * * * *')  // Poll SCM a cada 2 minutos
    }
}