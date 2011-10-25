# pass arguments to prove with "::" seperator. E.g. prove -l t/002_Tool.t :: arg1 arg2 
# e.g. prove -l :: ec2-184-73-94-115.compute-1.amazonaws.com /path/to/key.pem 
use Test::Spec;
use App::Galaxy::Devel::Tool;
use Data::Dumper;
use File::chdir;
use File::Path qw(remove_tree);
my $host = $ARGV[0]; 
my $key_path = $ARGV[1]; 
my $dist_name = "GalaxyX-Tool-test"; 
my $dist_name_suffix = "test";
my %opts = ( key_path => $key_path, strict_mode => 0, user => "ubuntu" ); 

# before doing anything check that we don't have a distribution sitting there because of a previous failed test
remove_tree( "GalaxyX-Tool-test") if stat("GalaxyX-Tool-test"); 

  describe "remote commands: " => sub {
     my $tool_dev;
     
     before sub {
       $tool_dev = App::Galaxy::Devel::Tool->new( host => $host, key_path => $key_path, ssh_opts => \%opts, dist_name_suffix => $dist_name_suffix, custom_tool_dir => 'myTools');
       
       $tool_dev->mint_dzil($dist_name_suffix); #mint a test distribution
     };
     
     it "-should return appropriate response on not being able to install module" => sub {     
            
       $CWD = $dist_name;    #change into distribution dir                 
       $tool_dev->build_dzil;       
        SKIP : {
          skip "No pass key and remote host", 3 if ( !defined( @ARGV ) ); 
          
          ok( $tool_dev->send_remote->[0]);             
          
          like($tool_dev->install_remote->[0], qr/Successfully/ );
          
          like($tool_dev->section_tool_grep_tool_conf->[0], qr/<tool file/ );   
          
          my $check_custom_tool_dir_exists = $tool_dev->check_custom_tool_dir_exists;  
          like($check_custom_tool_dir_exists->[0], qr/\/mnt\/galaxyTools.+/);        
            
          SKIP : {
             # create directory
             skip "If its already created don't run this test?", 1 if ($check_custom_tool_dir_exists->[0] =~ qr/galaxyTools/);
             my $ct = $tool_dev->create_custom_tool_dir;
             ok( $ct );	
             warn Dumper $ct;  
           };
           #warn Dumper $tool_dev->extract_in_tmp('cfg');
           # extract  
           #warn Dumper $tool_dev->copy_to_custom_tool_dir('cfg');
           # update
           #warn Dumper $tool_dev->new_section_tool_conf;
           # warn Dumper $tool_dev->section_exists_tool_conf;
           #is($tool_dev->section_exists_tool_conf,'    <section name="yourTools" id="idYourTools">'."\n", "Found a match"); 
           #warn Dumper $tool_dev->section_tool_exists_tool_conf;
           #ok( ! $tool_dev->section_tool_exists_tool_conf, "No match found");
           #warn Dumper $tool_dev->update_section_tool_conf;
           ## clean up remote stuff
           # restore backup in config file
           #warn "Restoring remote cfg file";
           #warn Dumper $tool_dev->restore_remote_tool_conf('sec');         
        };
     };     
     after sub {
       #clean up
       $CWD = '..';
       remove_tree( "GalaxyX-Tool-test");       
     };   
  };
runtests unless caller;