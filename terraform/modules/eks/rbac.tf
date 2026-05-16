resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

resource "kubernetes_role" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = "jenkins"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["create", "delete", "get", "list", "watch", "patch", "update"]
  }

  # fixes the 403 - exec into kaniko pod
  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create", "get"]
  }

  # read pod logs from jenkins UI
  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list", "watch"]
  }

  # kaniko needs to read ecr secret
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get"]
  }

  # needed for pipeline status reporting
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = "jenkins"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "jenkins-group"   # matches your aws-auth mapping
    api_group = "rbac.authorization.k8s.io"
  }
}