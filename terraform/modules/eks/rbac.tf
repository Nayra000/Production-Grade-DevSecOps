resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

resource "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
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
    verbs      = ["create", "delete", "get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = "jenkins"
  }

  subject {
    kind      = "Group"
    name      = "jenkins-group"
    api_group = "rbac.authorization.k8s.io"
  }

  role_ref {
    kind      = "Role"
    name      = "jenkins"
    api_group = "rbac.authorization.k8s.io"
  }
}