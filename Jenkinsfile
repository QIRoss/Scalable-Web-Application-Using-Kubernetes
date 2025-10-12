pipeline {
    agent {
        kubernetes {
            cloud 'minikube-local'
            label 'jenkins-agent-basic'
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  namespace: hextris
spec:
  containers:
  - name: main
    image: alpine:latest
    command: ['sleep']
    args: ['999999']
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
'''
        }
    }
    
    options {
        disableConcurrentBuilds()
    }
    
    stages {
        stage('Test') {
            steps {
                container('main') {
                    script {
                        echo "🎉 Estou rodando no Minikube!"
                        sh '''
                        echo "✅ Funcionando perfeitamente!"
                        echo "📅 Data: $(date)"
                        echo "🏷️ Build: ${BUILD_NUMBER}"
                        echo "💻 Hostname: $(hostname)"
                        echo "=== Informações ==="
                        uname -a
                        cat /etc/os-release | head -3
                        echo "=== Lista de arquivos ==="
                        ls -la
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "🎯 Pipeline executado no Minikube - Build #${BUILD_NUMBER}"
        }
    }
}