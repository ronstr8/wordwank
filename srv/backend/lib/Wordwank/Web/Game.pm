package Wordwank::Web::Game;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use v5.36;
use utf8;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Util;
use UUID::Tiny qw(:std);
use Wordwank::Util::NameGenerator;

my $DEFAULT_LANG = $ENV{DEFAULT_LANG} || 'en';

sub generate_procedural_name ($id) {
    return Wordwank::Util::NameGenerator->new->generate(4, 1, $id);
}

sub websocket ($self) {
    $self->reseed_prng();
    $self->inactivity_timeout(3600);

    # Always use UUID for player IDs
    my $player_id = $self->param('id') || create_uuid_as_string(UUID_V4);
    my $schema    = $self->app->schema;
    my $app       = $self->app;

    my $lang = $self->param('lang') || $self->req->headers->header('Accept-Language') || 'en';

    # 1. Identity & Database Setup
    my $player = $schema->resultset('Player')->find_or_create({
        id       => $player_id,
        nickname => generate_procedural_name($player_id),
        language => $lang,
    });

    # Send identity immediately
    $self->send({json => {
        type    => 'identity',
        payload => { 
            id       => $player->id, 
            name     => $player->nickname,
            language => $player->language,
            config   => {
                tiles       => $app->scorer->tile_counts($player->language // $DEFAULT_LANG),
                unicorns    => $app->scorer->unicorns($player->language // $DEFAULT_LANG),
                tile_values => $app->scorer->generate_tile_values($player->language // $DEFAULT_LANG),
                languages   => $app->languages,
            }
        }
    }});

    # 2. Connection Tracking
    my $client_id = "$self"; # Unique stringified controller
    $app->log->debug("Player $player_id connected via $client_id");

    $self->on(message => sub ($c, $msg) {
        my $bytes = utf8::is_utf8($msg) ? Mojo::Util::encode('UTF-8', $msg) : $msg;
        my $data = eval { decode_json($bytes) };
        if ($@) {
            $c->app->log->error("Invalid JSON from $player_id: $@");
            return;
        }

        my $type    = $data->{type}    // '';
        my $payload = $data->{payload} // {};

        if ($type eq 'join') {
            $c->app->game_manager->join_player($c, $player, $payload);
        }
        elsif ($type eq 'chat') {
            $c->app->game_manager->handle_chat($c, $player, $payload);
        }
        elsif ($type eq 'play') {
            $c->app->game_manager->handle_play($c, $player, $payload);
        }
        elsif ($type eq 'set_language') {
            $c->app->game_manager->handle_set_language($c, $player, $payload);
        }
    });

    $self->on(finish => sub ($c, $code, $reason) {
        $c->app->game_manager->handle_disconnect($player->id);
    });
}

1;
