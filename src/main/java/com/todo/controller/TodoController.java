package com.todo.controller;

import com.todo.model.Todo;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;

@RestController
@RequestMapping("/todos")
@CrossOrigin(origins = "*")
public class TodoController {

    private final List<Todo> todos = new ArrayList<>();
    private final AtomicLong counter = new AtomicLong();

    @GetMapping
    public List<Todo> getAll() {
        return todos;
    }

    @PostMapping
    public Todo create(@RequestBody Todo todo) {
        todo.setId(counter.incrementAndGet());
        todos.add(todo);
        return todo;
    }

    @PatchMapping("/{id}")
    public Todo toggle(@PathVariable Long id) {
        return todos.stream()
                .filter(t -> t.getId().equals(id))
                .findFirst()
                .map(t -> { t.setCompleted(!t.isCompleted()); return t; })
                .orElseThrow(() -> new RuntimeException("Todo not found"));
    }

    @DeleteMapping("/{id}")
    public void delete(@PathVariable Long id) {
        todos.removeIf(t -> t.getId().equals(id));
    }

    @GetMapping("/health")
    public String health() {
        return "ok";
    }
}
