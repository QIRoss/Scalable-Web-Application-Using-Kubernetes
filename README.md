# Scalable-Web-Application-Using-Kubernetes
Docker, NginX, Helm, Ingress, Terraform and Jenkins to deploy an example app

## Application

Use a simple web application ([Hextris](https://github.com/Hextris/hextris))

Create a Dockerfile to containerize the application.

Provide a Helm chart to deploy the application.

### Generate/Run image (local test)

```
docker build -t hextris:latest .
docker run -d -p 80:80 --name hextris-test hextris:latest
```

