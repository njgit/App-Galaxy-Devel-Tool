# functional tests
use Test::More tests => 1;
use App::Galaxy::Devel::Tool;
use File::Copy;
## Do some initial things before testing.
## Save current config file if it exists.
my $cfg_path = App::Galaxy::Devel::Tool->new->local_config_file_path;
copy($cfg_path, $cfg_path.'bak') if stat($cfg_path);

my $setup_path = App::Galaxy::Devel::Tool->new->local_config_setup_file_path;
copy($setup_path, $setup_path.'bak') if stat($setup_path);
ok(1);














