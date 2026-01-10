package Wordwank::Schema::Result::Player;
use Moose;
use MooseX::NonMoose;
extends 'DBIx::Class::Core';
use UUID::Tiny qw(:std);
use DateTime;
use Crypt::URandom;

__PACKAGE__->table('players');
__PACKAGE__->load_components(qw/InflateColumn::DateTime TimeStamp/);
__PACKAGE__->add_columns(
    id => {
        data_type => 'uuid',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    nickname => {
        data_type => 'text',
        is_nullable => 1,
    },
    real_name => {
        data_type => 'text',
        is_nullable => 1,
    },
    email => {
        data_type => 'text',
        is_nullable => 1,
    },
    created_at => {
        data_type => 'timestamp with time zone',
        set_on_create => 1,
    },
    last_login_at => {
        data_type => 'timestamp with time zone',
        is_nullable => 1,
    },
    language => {
        data_type => 'text',
        is_nullable => 0,
        default_value => 'en',
    }
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([qw/nickname/]);
__PACKAGE__->add_unique_constraint([qw/email/]);

__PACKAGE__->has_many(
    plays => 'Wordwank::Schema::Result::Play',
    'player_id'
);

__PACKAGE__->has_many(
    identities => 'Wordwank::Schema::Result::PlayerIdentity',
    'player_id'
);

__PACKAGE__->has_many(
    passkeys => 'Wordwank::Schema::Result::PlayerPasskey',
    'player_id'
);

__PACKAGE__->has_many(
    sessions => 'Wordwank::Schema::Result::Session',
    'player_id'
);

sub create_session {
    my ($self) = @_;
    my $session_token = unpack 'H*', Crypt::URandom::urandom(32);
    
    return $self->create_related('sessions', {
        id => $session_token,
        expires_at => DateTime->now->add(days => 30),
    });
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
