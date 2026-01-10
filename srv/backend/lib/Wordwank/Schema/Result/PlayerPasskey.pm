package Wordwank::Schema::Result::PlayerPasskey;
use Moose;
use MooseX::NonMoose;
extends 'DBIx::Class::Core';

__PACKAGE__->table('player_passkeys');
__PACKAGE__->load_components(qw/InflateColumn::DateTime TimeStamp/);
__PACKAGE__->add_columns(
    id => {
        data_type => 'bigint',
        is_auto_increment => 1,
    },
    player_id => {
        data_type => 'uuid',
        is_foreign_key => 1,
    },
    credential_id => {
        data_type => 'bytea',
        is_nullable => 0,
    },
    public_key => {
        data_type => 'bytea',
        is_nullable => 0,
    },
    sign_count => {
        data_type => 'bigint',
        default_value => 0,
    },
    created_at => {
        data_type => 'timestamp with time zone',
        set_on_create => 1,
    }
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([qw/credential_id/]);

__PACKAGE__->belongs_to(
    player => 'Wordwank::Schema::Result::Player',
    'player_id'
);

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
