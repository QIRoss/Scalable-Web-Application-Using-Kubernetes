pipeline {
    agent {
        kubernetes {
            cloud 'minikube-local'
            label 'jenkins-agent-test'
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
    env:
    - name: JENKINS_URL
      value: "http://host.minikube.internal:8080"
    - name: JENKINS_TUNNEL  
      value: "host.minikube.internal:50000"

  - name: network-test
    image: curlimages/curl:latest
    command: ['sleep']
    args: ['3600']
'''
        }
    }
    
    options {
        disableConcurrentBuilds()
    }
    
    stages {
        stage('Test Network') {
            steps {
                container('network-test') {
                    script {
                        sh '''
                        echo "🔍 Testing connectivity to Jenkins..."
                        echo "=== Testing Jenkins URL ==="
                        curl -v http://host.minikube.internal:8080 || echo "❌ Cannot reach Jenkins"
                        
                        echo "=== Testing Jenkins Tunnel ==="
                        nc -zv host.minikube.internal 50000 || echo "❌ Cannot reach Jenkins tunnel"
                        
                        echo "=== Network Info ==="
                        cat /etc/hosts
                        ping -c 2 host.minikube.internal
                        '''
                    }
                }
            }
        }
    }
}