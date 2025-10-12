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

  - name: tools
    image: alpine:latest
    command: ['sleep']
    args: ['999999']
'''
        }
    }
    
    stages {
        stage('Clean Start') {
            steps {
                container('tools') {
                    sh '''
                    echo "🎉 NOVO INÍCIO!"
                    echo "Todos os pods antigos foram limpos"
                    echo "Build: ${BUILD_NUMBER}"
                    '''
                }
            }
        }
    }
}