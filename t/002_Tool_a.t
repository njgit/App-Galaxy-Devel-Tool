# pass arguments to prove, with "::" seperator. E.g. prove -l t/002_Tool.t :: arg1 arg2 
use strict;
use Test::Spec;

use App::Galaxy::Devel::Tool;
use IO::All;
use File::chdir;
use File::Path qw(remove_tree);
use File::Remove qw(remove); 
use Data::Dumper;
use Config::Tiny;
use File::stat;

my $host = $ARGV[0]; #"ec2-184-73-94-115.compute-1.amazonaws.com";
my $key_path = $ARGV[1]; #"/home/nic/Dropbox/Work/AWS/njkey.pem";
my $dist_name = "GalaxyX-Tool-test"; 
my $dist_name_suffix = "test";


# before doing anything check that we don't have a distribution sitting there because of a previous failed
# test_file
remove_tree( "GalaxyX-Tool-test") if stat("GalaxyX-Tool-test"); 

describe "Tool Routines For" => sub {

  describe "a new distributions name" => sub {
    my $tool_dev;
    
    before sub {
      $tool_dev = App::Galaxy::Devel::Tool->new( dist_name  => $dist_name );    
    };

    it "should be the suffix of full distribution name" => sub {
      is( $tool_dev->dist_name_suffix_from_dist_name( $dist_name ), 'test');
      is( $tool_dev->dist_name_suffix, 'test');
    };
    
    before sub {
      $tool_dev = App::Galaxy::Devel::Tool->new( dist_name_suffix  => $dist_name_suffix );
    };
    
    it "should give back the full distribution name if initialised with the name" => sub {
       is( $tool_dev->dist_name, $dist_name);            
    };
    
  };

  describe "commands executed locally: " => sub {
    
     my $tool_dev;
     
     before sub {
       $tool_dev = App::Galaxy::Devel::Tool->new( dist_name_suffix => $dist_name_suffix );      
     };
     
     it "can be be minted" => sub {
      my $minted = $tool_dev->mint_dzil($dist_name_suffix);
      ok( stat($dist_name) );
     };
     
     it "produces example template for basic cmd line script" => sub {
       my $bin_test < io("td/test_cmd_line_script.pl");
       is($tool_dev->template_bin, $bin_test);    
     };
     
     it "produces example cfg file for basic cmd line script" => sub {
       my $cfg_test < io("td/test_cmd_line_script_gxy_cfg_file.xml");
       is($tool_dev->template_cfg, $cfg_test);
     };
     
     
     
     after sub {
        remove_tree( "GalaxyX-Tool-test");       
     };
    
  };
 
  describe "commands executed remotely: " => sub {
     my $tool_dev;
     
     before sub {
       $tool_dev = App::Galaxy::Devel::Tool->new( dist_name_suffix => $dist_name_suffix );
       #mint a test distribution
       $tool_dev->mint_dzil($dist_name_suffix);
       # turn off ssh role
       $tool_dev->openssh_on(0);
       #change into distribution dir
       $CWD = $dist_name;
     };
    
     it "-> should return appropriate commands" => sub {     
       
       my $install_cmd = "sudo cpanm /tmp/GalaxyX-Tool-test-0.001.tar.gz 2>&1 1>/dev/null 0>/dev/null &";
       is($tool_dev->install_remote, $install_cmd); 
       
       my $install_module_remote_cmd = "sudo cpanm " . "test" . " 2>&1 1>/dev/null 0>/dev/null &";                  
       my $out = $tool_dev->install_module_remote( "test" );
       is( $out, $install_module_remote_cmd);
       
       my $send_file = "test_file";
       is($tool_dev->send_remote("test_file"), $send_file);
       
       my $extract_in_tmp = "cd /tmp;sudo -u galaxy tar -xmvf GalaxyX-Tool-test-0.001.tar.gz GalaxyX-Tool-test-0.001/cfg";
       #my $extract_in_tmp = "sudo -u galaxy tar -xmvf /tmp/GalaxyX-Tool-test-0.001.tar.gz /tmp/GalaxyX-Tool-test-0.001/cfg";  
       is($tool_dev->extract_in_tmp('cfg'), $extract_in_tmp);
       
       my $check_custom_tool_dir_exists = 'stat -t /mnt/galaxyTools/galaxy-central/tools/myTools';
       is($tool_dev->check_custom_tool_dir_exists, $check_custom_tool_dir_exists);   
       
       my $create_custom_tool_dir = 'sudo -u galaxy mkdir /mnt/galaxyTools/galaxy-central/tools/myTools'; 
       is($tool_dev->create_custom_tool_dir, $create_custom_tool_dir);
       
       my $copy_to_custom_tool_dir = "sudo -u galaxy cp /tmp/GalaxyX-Tool-test-0.001/cfg/* /mnt/galaxyTools/galaxy-central/tools/myTools"; 
       is($tool_dev->copy_to_custom_tool_dir("cfg"), $copy_to_custom_tool_dir);
     
       my $new_section_tool_conf = qq{
     sudo -u galaxy sed -i'.bk.sec' '/<\\/toolbox>/ i\\    <section name="myTools" id="idMyTools">\\n    <\\/section>' /mnt/galaxyTools/galaxy-central/tool_conf.xml        
    };
       is($tool_dev->new_section_tool_conf, $new_section_tool_conf);
    
       my $update_section_tool_conf = qq{
     sudo -u galaxy sed -i'.bk.tool' '/<section name="myTools" id="idMyTools">/ a\\    <tool file="myTools/test.xml" id="idMyTools"\\/>' /mnt/galaxyTools/galaxy-central/tool_conf.xml
    };
       is($tool_dev->update_section_tool_conf, $update_section_tool_conf);
    
      my $section_exists_tool_conf = qq{
       grep '<section name="myTools" id="idMyTools">' /mnt/galaxyTools/galaxy-central/tool_conf.xml    
    } ;
    
    is($tool_dev->section_exists_tool_conf, $section_exists_tool_conf);
    
      my $section_tool_grep_tool_conf = qq{grep  '<tool file="myTools/test.xml" id="idMyTools"/>'  /mnt/galaxyTools/galaxy-central/tool_conf.xml} ;
      is($tool_dev->section_tool_grep_tool_conf, $section_tool_grep_tool_conf);
    
      my $add_admin =
      q{sudo -u galaxy perl -Mautobox::Core -i.bak -pe 'if(/^#admin_users/){ my $str = "admin_users =  super.duper\@gmail.com\n"; s/$_/$str/; } if( /^admin_users = (.+)/){ my $str = $1->concat( " super.duper\@gmail.com" )->split(" ")->uniq->join(" ")->concat("\n"); $str = "admin_users = $str"; s/$_/$str/;  }' /mnt/galaxyTools/galaxy-central/universe_wsgi.ini};
      is($tool_dev->add_admin(['super.duper@gmail.com']), $add_admin);
      
      my $restore_remote_tool_conf =  "sudo -u galaxy cp /mnt/galaxyTools/galaxy-central/tool_conf.xml.bk.tool /mnt/galaxyTools/galaxy-central/tool_conf.xml";   
      is($tool_dev->restore_remote_tool_conf('tool'), $restore_remote_tool_conf);
     
      my $make_conf_backup = 
      "sudo -u galaxy cp /mnt/galaxyTools/galaxy-central/tool_conf.xml /mnt/galaxyTools/galaxy-central/tool_conf.xml.bk.tool";
      is($tool_dev->make_conf_backup('tool'), $make_conf_backup);
      
      my $read_remote_cpanm_log = 'cat /home/ubuntu/.cpanm/build.log';
      is($tool_dev->read_remote_cpanm_log, $read_remote_cpanm_log);
     };
     
     after sub {
       #clean up
       remove_tree( "GalaxyX-Tool-test");       
     };   
  };

# Doesn't require remote login
 
  # new
  
  # setup/configs 
  
  # build
  
  # save
  
# Does require remote credentials  
  
  # push
  
  # install

};



runtests unless caller;
