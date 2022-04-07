resource "aws_elasticsearch_domain" "local_index" {
  domain_name           = "local"
  elasticsearch_version = "Elasticsearch_7.10"

  cluster_config {
    instance_type = "r4.large.elasticsearch"
  }
}
