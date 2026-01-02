package com.wordwank.playerd.controller;

import com.wordwank.playerd.model.Player;
import com.wordwank.playerd.repository.PlayerRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.Optional;

@RestController
@RequestMapping("/players")
public class PlayerController {

    @Autowired
    private PlayerRepository repository;

    @PostMapping("/{id}")
    public Player createPlayer(@PathVariable String id, @RequestParam String username) {
        Player player = new Player(id, username);
        return repository.save(player);
    }

    @GetMapping("/{id}")
    public Optional<Player> getPlayer(@PathVariable String id) {
        return repository.findById(id);
    }

    @PostMapping("/{id}/score")
    public Player reportScore(@PathVariable String id, @RequestParam long score) {
        Player player = repository.findById(id).orElse(new Player(id, id));
        player.setTotalScore(player.getTotalScore() + score);
        player.setGameCount(player.getGameCount() + 1);
        player.setLastSeen(System.currentTimeMillis() / 1000);
        return repository.save(player);
    }

    @GetMapping("/leaderboard")
    public Iterable<Player> getLeaderboard() {
        // In a real app, we'd use a sorted set in Redis, 
        // but for now we'll just return all and let the client or a simple sort handle it.
        return repository.findAll();
    }
}
