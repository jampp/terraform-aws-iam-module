data "aws_iam_policy_document" "policy" {
  for_each = var.policies

  version = lookup(each.value, "version", "2012-10-17")

  dynamic "statement" {
    for_each = each.value.statements
    content {
      sid    = lookup(statement.value, "sid", null)
      effect = lookup(statement.value, "effect", "Allow")

      actions     = lookup(statement.value, "actions", [])
      not_actions = lookup(statement.value, "not_actions", [])

      resources     = lookup(statement.value, "resources", [])
      not_resources = lookup(statement.value, "not_resources", [])

      dynamic "principals" {
        for_each = lookup(statement.value, "principals", [])
        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "not_principals" {
        for_each = lookup(statement.value, "not_principals", [])
        content {
          type        = not_principals.value.type
          identifiers = not_principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = lookup(statement.value, "conditions", [])
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_iam_policy" "policy" {
  for_each = var.policies

  name        = each.key
  path        = var.path
  description = each.value.description
  policy      = data.aws_iam_policy_document.policy[each.key].json

  tags = var.tags
}

module "role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  version = "5.3.0"

  role_name            = var.name
  role_description     = var.description
  role_path            = var.path
  max_session_duration = var.max_session_duration

  cluster_service_accounts = var.cluster_service_accounts

  role_permissions_boundary_arn = var.permissions_boundary_arn
  role_policy_arns = merge(
    { for key, policy in var.policies : key => aws_iam_policy.policy[key].arn },
    var.policy_arns
  )

  tags = var.tags

  depends_on = [
    aws_iam_policy.policy
  ]
}
