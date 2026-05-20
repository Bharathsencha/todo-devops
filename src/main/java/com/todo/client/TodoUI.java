package com.todo.client;

import com.todo.model.Todo;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.type.TypeReference;
import javafx.application.Application;
import javafx.application.Platform;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;
import javafx.stage.Stage;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;

public class TodoUI extends Application {

        private static final String API_URL = "http://127.0.0.1:8081/todos";

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();
    private final ObjectMapper mapper = new ObjectMapper();

    private VBox todoList;
    private Label countLabel;

    public static void main(String[] args) { launch(args); }

    @Override
    public void start(Stage stage) {
        stage.setTitle("Todo App");
        stage.setMinWidth(480);
        stage.setMinHeight(600);

        // ── Root ──────────────────────────────────────────────────────────────
        BorderPane root = new BorderPane();
        root.setStyle("""
                -fx-background-color: #1a1a2e;
                """);

        // ── Header ────────────────────────────────────────────────────────────
        VBox header = new VBox(4);
        header.setPadding(new Insets(28, 28, 20, 28));
        header.setStyle("-fx-background-color: #16213e;");

        Label title = new Label("Todo App");
        title.setFont(Font.font("System", FontWeight.BOLD, 26));
        title.setStyle("-fx-text-fill: #e2e8f0;");
        // ── Input Row ─────────────────────────────────────────────────────────
        HBox inputRow = new HBox(10);
        inputRow.setPadding(new Insets(16, 20, 14, 20));
        inputRow.setAlignment(Pos.CENTER);
        inputRow.setStyle("-fx-background-color: #16213e;");

        TextField inputField = new TextField();
        inputField.setPromptText("Add a new task…");
        inputField.setFont(Font.font(14));
        HBox.setHgrow(inputField, Priority.ALWAYS);
        inputField.setStyle("""
                -fx-background-color: #0f3460;
                -fx-text-fill: #e2e8f0;
                -fx-prompt-text-fill: #475569;
                -fx-background-radius: 8;
                -fx-border-radius: 8;
                -fx-padding: 8 12 8 12;
                -fx-font-size: 14;
                """);

        Button addBtn = new Button("Add");
        addBtn.setFont(Font.font("System", FontWeight.BOLD, 14));
        addBtn.setStyle("""
                -fx-background-color: #e94560;
                -fx-text-fill: white;
                -fx-background-radius: 8;
                -fx-cursor: hand;
                -fx-padding: 8 18 8 18;
                """);
        addBtn.setOnMouseEntered(e -> addBtn.setStyle("""
                -fx-background-color: #c73652;
                -fx-text-fill: white;
                -fx-background-radius: 8;
                -fx-cursor: hand;
                -fx-padding: 8 18 8 18;
                """));
        addBtn.setOnMouseExited(e -> addBtn.setStyle("""
                -fx-background-color: #e94560;
                -fx-text-fill: white;
                -fx-background-radius: 8;
                -fx-cursor: hand;
                -fx-padding: 8 18 8 18;
                """));

        inputRow.getChildren().addAll(inputField, addBtn);

        // ── Separator ─────────────────────────────────────────────────────────
        VBox topSection = new VBox(0, header, inputRow);
        root.setTop(topSection);

        // ── Todo List ─────────────────────────────────────────────────────────
        todoList = new VBox(8);
        todoList.setPadding(new Insets(16, 16, 16, 16));
        todoList.setStyle("-fx-background-color: #1a1a2e;");

        ScrollPane scrollPane = new ScrollPane(todoList);
        scrollPane.setFitToWidth(true);
        scrollPane.setHbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
        scrollPane.setStyle("""
                -fx-background: #1a1a2e;
                -fx-background-color: #1a1a2e;
                -fx-border-color: transparent;
                """);
        root.setCenter(scrollPane);

        // ── Footer ────────────────────────────────────────────────────────────
        HBox footer = new HBox();
        footer.setPadding(new Insets(10, 20, 10, 20));
        footer.setStyle("-fx-background-color: #16213e;");

        countLabel = new Label("0 items");
        countLabel.setStyle("-fx-text-fill: #64748b; -fx-font-size: 12;");
        footer.getChildren().add(countLabel);
        root.setBottom(footer);

        // ── Actions ───────────────────────────────────────────────────────────
        addBtn.setOnAction(e -> {
            String text = inputField.getText().trim();
            if (!text.isEmpty()) {
                createTodo(text);
                inputField.clear();
            }
        });
        inputField.setOnAction(e -> addBtn.fire());

        Scene scene = new Scene(root, 480, 600);
        stage.setScene(scene);
        stage.show();

        refreshTodos();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private HBox todoRow(Todo todo) {
        HBox row = new HBox(12);
        row.setAlignment(Pos.CENTER_LEFT);
        row.setPadding(new Insets(12, 14, 12, 14));
        row.setStyle("""
                -fx-background-color: #16213e;
                -fx-background-radius: 10;
                """);
        row.setOnMouseEntered(e -> row.setStyle("""
                -fx-background-color: #0f3460;
                -fx-background-radius: 10;
                """));
        row.setOnMouseExited(e -> row.setStyle("""
                -fx-background-color: #16213e;
                -fx-background-radius: 10;
                """));

        CheckBox check = new CheckBox();
        check.setSelected(todo.isCompleted());
        check.setStyle("-fx-cursor: hand;");

        Label text = new Label(todo.getTitle());
        text.setFont(Font.font(15));
        HBox.setHgrow(text, Priority.ALWAYS);
        if (todo.isCompleted()) {
            text.setStyle("-fx-text-fill: #475569; -fx-strikethrough: true;");
        } else {
            text.setStyle("-fx-text-fill: #cbd5e1;");
        }

        check.setOnAction(e -> toggleTodo(todo.getId()));

        Button del = new Button("✕");
        del.setFont(Font.font("System", FontWeight.BOLD, 11));
        del.setStyle("""
                -fx-background-color: #374151;
                -fx-text-fill: #9ca3af;
                -fx-background-radius: 6;
                -fx-cursor: hand;
                -fx-padding: 3 7 3 7;
                """);
        del.setOnMouseEntered(e2 -> del.setStyle("""
                -fx-background-color: #e94560;
                -fx-text-fill: white;
                -fx-background-radius: 6;
                -fx-cursor: hand;
                -fx-padding: 3 7 3 7;
                """));
        del.setOnMouseExited(e2 -> del.setStyle("""
                -fx-background-color: #374151;
                -fx-text-fill: #9ca3af;
                -fx-background-radius: 6;
                -fx-cursor: hand;
                -fx-padding: 3 7 3 7;
                """));
        del.setOnAction(e -> deleteTodo(todo.getId()));

        row.getChildren().addAll(check, text, del);
        return row;
    }

    private void refreshTodos() {
        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(API_URL))
                .GET().build();
        httpClient.sendAsync(req, HttpResponse.BodyHandlers.ofString())
                .thenApply(HttpResponse::body)
                .thenAccept(body -> {
                    try {
                        List<Todo> items = mapper.readValue(body, new TypeReference<>() {});
                        Platform.runLater(() -> {
                            todoList.getChildren().clear();
                            if (items.isEmpty()) {
                                Label empty = new Label("No todos yet. Add one above!");
                                empty.setStyle("-fx-text-fill: #475569; -fx-font-size: 14;");
                                empty.setPadding(new Insets(30, 0, 0, 0));
                                todoList.setAlignment(Pos.TOP_CENTER);
                                todoList.getChildren().add(empty);
                            } else {
                                todoList.setAlignment(Pos.TOP_LEFT);
                                for (Todo t : items) todoList.getChildren().add(todoRow(t));
                            }
                            countLabel.setText(items.size() + (items.size() == 1 ? " item" : " items"));
                        });
                    } catch (Exception ex) { ex.printStackTrace(); }
                })
                .exceptionally(ex -> { ex.printStackTrace(); return null; });
    }

    private void createTodo(String title) {
        try {
            Todo t = new Todo(); t.setTitle(title); t.setCompleted(false);
            String json = mapper.writeValueAsString(t);
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(API_URL))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json)).build();
            httpClient.sendAsync(req, HttpResponse.BodyHandlers.ofString())
                    .thenAccept(r -> refreshTodos());
        } catch (Exception ex) { ex.printStackTrace(); }
    }

    private void toggleTodo(long id) {
        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(API_URL + "/" + id))
                .method("PATCH", HttpRequest.BodyPublishers.noBody()).build();
        httpClient.sendAsync(req, HttpResponse.BodyHandlers.ofString())
                .thenAccept(r -> refreshTodos());
    }

    private void deleteTodo(long id) {
        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(API_URL + "/" + id))
                .DELETE().build();
        httpClient.sendAsync(req, HttpResponse.BodyHandlers.ofString())
                .thenAccept(r -> refreshTodos());
    }
}
