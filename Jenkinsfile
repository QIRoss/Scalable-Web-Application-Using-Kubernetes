pipeline {
    agent {
        kubernetes {
            cloud 'minikube-local'
            label 'jenkins-agent-no-jnlp'
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  namespace: hextris
  labels:
    jenkins: agent
spec:
  containers:
  - name: main
    image: alpine:latest
    command: ['sh']
    args: ['-c', 'echo "🚀 Container principal rodando" && sleep 999999']
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
    env:
    - name: JENKINS_URL
      value: "none"  # ⚠️ Isso previne auto-injeção do JNLP
'''
            // ⚠️ ADICIONE ESTA LINHA PARA PREVENIR JNLP
            idleMinutes 5
        }
    }
    
    options {
        disableConcurrentBuilds()
        skipDefaultCheckout true
    }
    
    stages {
        stage('Debug Pod') {
            steps {
                container('main') {
                    script {
                        echo "🎉 FINALMENTE! Sem JNLP!"
                        sh '''
                        echo "✅ Estou rodando no Minikube SEM JNLP!"
                        echo "📅 Data: $(date)"
                        echo "🏷️ Build: ${BUILD_NUMBER}"
                        echo "💻 Hostname: $(hostname)"
                        echo "=== Containers no Pod ==="
                        ps aux
                        echo "=== Lista de processos ==="
                        cat /proc/1/cmdline | tr "\\0" " " && echo
                        echo "=== Arquivos no workspace ==="
                        find /home/jenkins/agent/ -type f 2>/dev/null | head -10 || echo "Nenhum workspace encontrado"
                        '''
                    }
                }
            }
        }
        
        stage('Check Kubernetes') {
            steps {
                container('main') {
                    script {
                        sh '''
                        echo "=== Testando acesso ao Kubernetes ==="
                        # Instalar kubectl se necessário
                        which kubectl || (apk add --no-cache curl && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x kubectl && mv kubectl /usr/local/bin/)
                        
                        # Verificar se temos acesso
                        kubectl get pods -n hextris 2>/dev/null || echo "❌ Sem acesso ao Kubernetes"
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "🎯 Pipeline executado SEM JNLP - Build #${BUILD_NUMBER}"
        }
    }
}