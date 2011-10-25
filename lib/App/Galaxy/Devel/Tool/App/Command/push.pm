#ABSTRACT: Push a distribution to a remote server
package App::Galaxy::Devel::Tool::App::Command::push;
use App::Galaxy::Devel::Tool::App -command;

#core
use strict;
use warnings;
use autodie;

#cpan
#use File::Path qw(make_path remove_tree);
use File::chdir;
use File::Spec::Functions qw(catdir);
use Data::Validate::Domain qw(is_hostname);
use Try::Tiny;
use File::HomeDir;
use Config::Tiny;

# lib
use App::Galaxy::Devel::Tool;


sub usage_desc { "galaxp push [OPTIONS] DIRECTORY" } 
sub abstract {
 "Pushes a distribution to a remote galaxy cloud instance."; 
}

sub description {
  "Pushes a distribution to a remote galaxy cloud instance.";
}

sub opt_spec {
   my ( $class, $app ) = @_;
    return ( 
           [ 'custom_tool_dir|d=s' => "Name of custom tool directory" ],
           [ 'key_path|k=s' => "Path to pem key." ],
           [ 'host|h=s' => "URL to galaxy cloud server"],
           [ 'no_restart|n' => "No restart" ],
    );
}  

sub validate_args {
  my ($self, $opt, $args) = @_;
} 
  
sub execute {
    my ($self, $opt, $args) = @_;

    die "Requires DIRECTORY" unless my $dir = $args->[0];
    
    my $custom_tool_dir = $opt->{custom_tool_dir};     
     
    print "No key_path defined, attempt to use config file..\n" unless defined($opt->{ key_path });
    print "No host defined, attempt to use config file..\n" unless defined($opt->{ host });
    
    my $tool_dev = App::Galaxy::Devel::Tool->new( dist_name => catdir( $dir ) ); #catdir ensures trailing slashes don't interfere
    $tool_dev->host( $opt->{ host } ) if ( defined( $opt->{ host } ) ); # otherwise they will be loaded from config
    $tool_dev->key_path( $opt->{ key_path } ) if ( defined( $opt->{ key_path }  ) );
    # this sets the name of the custom directory
    $tool_dev->custom_tool_dir( $opt->{custom_tool_dir} ) if defined( $opt->{custom_tool_dir} );
    
    #change working directory    
    $CWD = $dir;  
    
    try { 
     
      $tool_dev->build_dzil($dir);       # build with dzil
      
      print "Connecting to galaxy cloud...\n"; 
      
      $tool_dev->send_remote;            # sends to /tmp on remote machine
     
      print "Installing cpan modules... (this may take a while)\n";
      speak( $tool_dev->install_remote );         # uses cpanm to install into  home/galaxy/perl5 directory

      
      my $exists = $tool_dev->check_custom_tool_dir_exists;
      print $exists ? "Found custom directory...\n" : "Creating custom tool directory..\n";
      $tool_dev->create_custom_tool_dir unless ($exists);   # unless it exists, create the directory to place the scripts and xml files in
      $tool_dev->new_section_tool_conf  unless ($exists);   # unless it exists, add a section entry into conf_tool.xml
      
      print "Extracting to appropriate directories... \n";
      $tool_dev->extract_in_tmp('cfg');          # extracts directory DISTNAME/cfg in /tmp
      $tool_dev->copy_to_custom_tool_dir('cfg'); # copies from /cfg dir to  galaxyTools custom directory
      $tool_dev->extract_in_tmp('bin'); 
      $tool_dev->copy_to_custom_tool_dir('bin');   
      
      $exists = 1;
      $exists = 0 if ($tool_dev->section_tool_grep_tool_conf->[1] eq "child exited with code 1"); #no results
      $tool_dev->update_section_tool_conf unless ( $exists ); # unless it exists, insert tool description in conf_tool.xml, 
      
      unless ( defined( $opt->{no_restart} ) ) {
        print "Attempt to restart galaxy server...\n";
        my $response = $tool_dev->restart_galaxy_cloud_service;
        die ( "Could not restart galaxy .. \ncontent: ", $response->{content}, " reason: ", $response->{reason}, " status code: ", $response->{status} ) unless( $response->{success} );
        print $response->{content}, "\n";
      }
    }
    catch {
      print "Error: $_";      
    };
}

sub speak {
  my $out = shift;
  if(ref($out) eq 'ARRAY') {
    for ( 0 .. @$out-1 ) { print $out->[$_], "\n"; }    
  }; 
}

1;