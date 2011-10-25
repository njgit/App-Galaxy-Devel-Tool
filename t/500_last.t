use Test::More tests => 1;
use App::Galaxy::Devel::Tool;
use File::Copy;
# put the config file back to how it was
my $cfg_path = App::Galaxy::Devel::Tool->new->local_config_file_path;
copy( $cfg_path.'bak', $cfg_path) if ( stat($cfg_path.'bak') );

my $setup_path = App::Galaxy::Devel::Tool->new->local_config_setup_file_path;
copy($setup_path.'bak', $setup_path ) if stat($setup_path.'bak');
ok(1);