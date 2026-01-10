package Wordwank::Schema::ResultSet::Player;
use base 'DBIx::Class::ResultSet';
use UUID::Tiny qw(:std);
use DateTime;
use Wordwank::Util::NameGenerator;

sub find_or_create_from_google {
    my ($self, $user_info) = @_;
    my $schema = $self->result_source->schema;
    
    my $google_id = $user_info->{sub};
    my $email = $user_info->{email};
    my $name = $user_info->{name};

    # Start a transaction
    return $schema->txn_do(sub {
        # Check for identity first
        my $identity = $schema->resultset('PlayerIdentity')->find({
            provider => 'google',
            provider_id => $google_id,
        });

        if ($identity) {
            my $player = $identity->player;
            $player->update({ 
                last_login_at => DateTime->now,
                real_name     => $name,
            });
            return $player;
        }

        # Check for player by email if no identity (account linkage)
        my $player = $self->find({ email => $email });
        
        if (!$player) {
            # New Player
            my $gen = Wordwank::Util::NameGenerator->new;
            $player = $self->create({
                id => create_uuid_as_string(UUID_V4),
                nickname => $gen->generate($google_id),
                real_name => $name,
                email => $email,
                last_login_at => DateTime->now,
            });
        }

        # Create identity
        $player->create_related('identities', {
            provider => 'google',
            provider_id => $google_id,
        });

        return $player;
    });
}

sub create_session {
    my ($player) = @_;
    my $session_token = unpack 'H*', Crypt::URandom::urandom(32);
    
    return $player->create_related('sessions', {
        id => $session_token,
        expires_at => DateTime->now->add(days => 30),
    });
}

1;
