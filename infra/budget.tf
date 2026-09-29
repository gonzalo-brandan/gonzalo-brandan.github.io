# Monthly cost budget for the whole AWS account. Budgets only send alerts;
# they never stop or limit services.

locals {
  budget_alerts = {
    early_warning = { threshold = var.budget_warning_amount, type = "ACTUAL" }
    forecast_over = { threshold = var.budget_limit_amount, type = "FORECASTED" }
    limit_reached = { threshold = var.budget_limit_amount, type = "ACTUAL" }
  }
}

resource "aws_budgets_budget" "monthly" {
  name         = "monthly-cost"
  budget_type  = "COST"
  limit_amount = var.budget_limit_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = local.budget_alerts
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold
      threshold_type             = "ABSOLUTE_VALUE"
      notification_type          = notification.value.type
      subscriber_email_addresses = [var.budget_alert_email]
    }
  }
}
