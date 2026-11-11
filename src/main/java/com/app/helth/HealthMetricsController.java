package com.app.helth;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
public class HealthMetricsController {
	@GetMapping("/api/health")
	public Map<String, String> health() {
		return Map.of("status", "UP");
	}

	@GetMapping("/hello")
	public String hello() {
		return "Hello, World!";
	}
}
