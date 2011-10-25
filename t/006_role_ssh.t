
# Want to test a couple of ssh commands to
# ensure this works.
{
package TestRoleSSH;

use Any::Moose;

has 'host' => (isa => 'Str', is => 'rw', default => sub { 'ec2-75-101-225-190.compute-1.amazonaws.com'});
has 'key_path' => (isa => 'Str', is => 'rw');
has 'ssh_opts' => ( isa => 'HashRef', is => 'rw', default => sub { { key_path => '/home/nic/Dropbox/Work/AWS/njkey.pem', strict_mode => 0, user => 'ubuntu'} });

with 'App::Galaxy::Devel::Tool::Role::SSH';

# fake install remote command
sub install_remote {
	my $self = shift;
	my $cmd = 'echo install'; 
}
sub install_module_remote {
}
sub extract_in_tmp {
} 
sub check_custom_tool_dir_exists {
} 
sub create_custom_tool_dir {
}
sub copy_to_custom_tool_dir {
} 
sub new_section_tool_conf {
}
sub update_section_tool_conf {
}
sub section_exists_tool_conf {
} 
sub add_admin {
}
sub restore_remote_tool_conf {
} 
sub make_conf_backup {
}   
sub read_remote_cpanm_log {
}
sub section_tool_grep_tool_conf {
}
sub send_remote {
}
};

use Test::Spec;
use App::Galaxy::Devel::Tool;

describe "SSH" => sub {
   my $test;
 
  before sub {
     $test = TestRoleSSH->new();
  };	

  it "should have its properties defined" => sub {     
     my $out = $test->host;
      
     ok(defined($out)); 
  };
  
  SKIP: {
    skip "No pass key and remote host", 2 if ( !defined( @ARGV ) ); 
    it "should execute test commands on host " => sub {    
        $test->host($ARGV[0]);
        $test->key_path($ARGV[1]);   
       is($test->install_remote->[0], "install\n");
     };
  }; 
		
};

runtests unless caller;