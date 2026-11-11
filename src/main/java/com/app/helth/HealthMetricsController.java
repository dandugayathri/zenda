package com.app.helth;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthMetricsController {

	@GetMapping("/hello")
	public String hello() {
		return "Hello, World!";
	}
}
