package com.wordwank.playerd.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.redis.core.RedisHash;
import java.io.Serializable;

@RedisHash("Player")
public class Player implements Serializable {
    @Id
    private String playerId;
    private String username;
    private String currentGameId;
    private long totalScore;
    private long gameCount;
    private long lastSeen;

    public Player() {}

    public Player(String playerId, String username) {
        this.playerId = playerId;
        this.username = username;
        this.lastSeen = System.currentTimeMillis() / 1000;
    }

    // Getters and Setters
    public String getPlayerId() { return playerId; }
    public void setPlayerId(String playerId) { this.playerId = playerId; }
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    public String getCurrentGameId() { return currentGameId; }
    public void setCurrentGameId(String currentGameId) { this.currentGameId = currentGameId; }
    public long getTotalScore() { return totalScore; }
    public void setTotalScore(long totalScore) { this.totalScore = totalScore; }
    public long getGameCount() { return gameCount; }
    public void setGameCount(long gameCount) { this.gameCount = gameCount; }
    public long getLastSeen() { return lastSeen; }
    public void setLastSeen(long lastSeen) { this.lastSeen = lastSeen; }
}
