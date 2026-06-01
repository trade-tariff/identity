region        = "eu-west-2"
environment   = "production"
cpu           = 1024
memory        = 2048
service_count = 1
min_capacity  = 1
max_capacity  = 5
# Temporarily pinned autoscaling cooldown values in Production to preserve existing behaviour while testing changes in staging
scale_in_cooldown  = 0
scale_out_cooldown = 0

enable_observability_alerts = true
