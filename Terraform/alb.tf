resource "aws_lb" "public" {
  name               = "${var.project_name}-alb-public"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_public.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "${var.project_name}-alb-public"
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-tg-frontend"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-tg-frontend"
  }
}

resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_target_group_attachment" "frontend_a" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "frontend_b" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend_b.id
  port             = 80
}

resource "aws_lb" "internal" {
  name               = "${var.project_name}-alb-internal"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_internal.id]
  subnets            = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "${var.project_name}-alb-internal"
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-tg-backend"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-tg-backend"
  }
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

resource "aws_lb_target_group_attachment" "backend_a" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend_a.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "backend_b" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend_b.id
  port             = 8080
}
