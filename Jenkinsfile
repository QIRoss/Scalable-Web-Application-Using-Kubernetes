pipeline {
    agent {
        kubernetes {
            cloud 'minikube-local'
            label 'jenkins-agent'
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
    args: ['infinity']
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock

  - name: kubectl
    image: bitnami/kubectl:latest
    command: ['sleep']
    args: ['infinity']

  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
        }
    }
    
    // 🔥 ADICIONE ESTAS OPÇÕES PARA EVITAR CONCORRÊNCIA
    options {
        disableConcurrentBuilds()
        timeout(time: 10, unit: 'MINUTES')
    }
    
    triggers {
        pollSCM('H/2 * * * *')
    }
    
    stages {
        stage('Cleanup Previous Pods') {
            steps {
                container('kubectl') {
                    script {
                        sh '''
                        echo "🧹 Cleaning up previous Jenkins agent pods..."
                        # Listar e deletar pods antigos do Jenkins
                        kubectl get pods -n hextris -l jenkins=agent --no-headers=true | awk '{print $1}' | xargs --no-run-if-empty kubectl delete pod -n hextris
                        sleep 5
                        '''
                    }
                }
            }
        }
        
        stage('Test') {
            steps {
                echo "✅ Build único rodando!"
                container('docker') {
                    sh 'docker --version'
                }
                container('kubectl') {
                    sh 'kubectl get pods -n hextris'
                }
            }
        }
    }
}