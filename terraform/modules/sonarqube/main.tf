resource "kubernetes_namespace" "sonarqube" {
  metadata {
    name = "sonarqube"
  }
}

resource "helm_release" "sonarqube" {
  name       = "sonarqube"
  namespace  = kubernetes_namespace.sonarqube.metadata[0].name

  repository = "https://SonarSource.github.io/helm-chart-sonarqube"
  chart      = "sonarqube"
  version    = "10.0.0"

  values = [
    file("${path.module}/sonarqube-values.yaml")
  ]

  depends_on = [
    kubernetes_namespace.sonarqube
  ]
}