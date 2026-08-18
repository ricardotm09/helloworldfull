package main

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("container %q must not run privileged", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  not input.spec.template.spec.securityContext.runAsNonRoot
  msg := "pod securityContext.runAsNonRoot must be true"
}

deny[msg] {
  input.kind == "Deployment"
  not input.spec.template.spec.securityContext.runAsUser
  msg := "pod securityContext.runAsUser must be set to a non-root UID"
}

deny[msg] {
  input.kind == "Deployment"
  input.spec.template.spec.securityContext.runAsUser == 0
  msg := "pod securityContext.runAsUser must not be 0"
}

deny[msg] {
  input.kind == "Deployment"
  input.spec.replicas < 2
  msg := "deployment replicas should be at least 2 for high availability"
}

deny[msg] {
  input.kind == "Deployment"
  input.spec.strategy.type != "RollingUpdate"
  msg := "deployment strategy.type must be RollingUpdate"
}

deny[msg] {
  input.kind == "Deployment"
  input.spec.strategy.rollingUpdate.maxUnavailable != 0
  msg := "deployment strategy.rollingUpdate.maxUnavailable must be 0"
}

deny[msg] {
  input.kind == "Deployment"
  input.spec.strategy.rollingUpdate.maxSurge != 1
  msg := "deployment strategy.rollingUpdate.maxSurge must be 1"
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.allowPrivilegeEscalation == false
  msg := sprintf("container %q must set securityContext.allowPrivilegeEscalation to false", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.requests.cpu
  msg := sprintf("container %q is missing resources.requests.cpu", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.requests.memory
  msg := sprintf("container %q is missing resources.requests.memory", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.cpu
  msg := sprintf("container %q is missing resources.limits.cpu", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.memory
  msg := sprintf("container %q is missing resources.limits.memory", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.readinessProbe
  msg := sprintf("container %q is missing readinessProbe", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.livenessProbe
  msg := sprintf("container %q is missing livenessProbe", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not startswith(container.image, "${IMAGE_NAME}")
  msg := sprintf("container %q image must be injected via ${IMAGE_NAME} template", [container.name])
}

deny[msg] {
  input.kind == "Service"
  not input.spec.ports[_].name == "http"
  msg := "service must define a named port 'http' for stable metrics scraping"
}
