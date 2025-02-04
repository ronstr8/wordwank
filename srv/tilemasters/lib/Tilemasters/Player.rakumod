unit module Tilemasters::Player;

class Player {
    method validate-token(Str $auth-header) {
        # Stub for OAuth validation (to be implemented)
        return $auth-header ?? 'player-123' !! Nil;
    }
}
