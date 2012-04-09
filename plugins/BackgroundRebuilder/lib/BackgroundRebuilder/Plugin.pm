package BackgroundRebuilder::Plugin;
use strict;

sub _cb_cms_post_save_entry {
    my ( $cb, $app, $obj, $original ) = @_;
    return 1 unless $obj->status == MT::Entry::RELEASE();
    force_background_task(
        sub { $app->rebuild_entry( Entry => $obj->id,
                                   BuildDependencies => 1 );
        }
    );
    my $to_ping_urls = $app->param( 'to_ping_urls' );
    my ( $atom_id, $old_status );
    if ( defined $original ) {
        $atom_id = $original->atom_id;
        $old_status = $original->status;
    } else {
        $old_status = 0;
    }
    if ( ( $to_ping_urls ) || (! $atom_id ) ) {
        force_background_task(
            sub { $app->ping_and_save( Blog  => $obj->blog,
                                       Entry => $obj,
                                       OldStatus => $old_status );
            }
        );
    }
    my $query_str;
    if ( defined $original ) {
        $query_str = $app->uri_params( mode => 'view',
                                       args => { _type   => 'entry',
                                                 id      => $obj->id,
                                                 blog_id => $obj->blog_id,
                                                 saved_changes => 1,
        } );
    } else {
        $query_str = $app->uri_params( mode => 'view',
                                       args => { _type   => 'entry',
                                                 id      => $obj->id,
                                                 blog_id => $obj->blog_id,
                                                 saved_added => 1,
        } );
    }
    my $mt_path = $app->base . $app->uri();
    my $return_path = $mt_path . $query_str;
    my $redirect = 'Location: ' . $return_path . "\n\n";
    $app->print( $redirect );
    return 1;
}

sub force_background_task {
    my $app = MT->instance();
    my $default = $app->config->LaunchBackgroundTasks;
    $app->config( 'LaunchBackgroundTasks', 1 );
    my $res = MT::Util::start_background_task( @_ );
    $app->config( 'LaunchBackgroundTasks', $default );
    return $res;
}

1;