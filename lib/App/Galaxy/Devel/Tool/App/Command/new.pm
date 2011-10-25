# creates the script skeleton
package App::Galaxy::Devel::Tool::App::Command::new;
use App::Galaxy::Devel::Tool::App -command;

#core
use strict;
use warnings;
use autodie;

#cpan
use File::Path qw(make_path remove_tree);
use File::Spec::Functions qw(catdir);
use IO::All;
use Try::Tiny;
use Dist::Zilla;

use App::Galaxy::Devel::Tool;

sub usage_desc { "galaxp new [OPTIONS] NAME" } 
sub abstract {
  "Creates a new Dist::Zilla distribution with a default template for integrating to galaxy cloud instances.";
}

sub description {
  "By default this command creates a new Dist::Zilla distribution, with an App::Cmd::Simple Structure and a default template\n"
 ."for integrating into Galaxy cloud instances. This distribution can then be built, sent and configured on the remote galaxy\n"
 ."host by using the push command.\n";
}

sub opt_spec {
   my ( $class, $app ) = @_;
    return (
      [ 'simple|s' => "Create a simple skeleton for command line application (not App::Cmd::Simple skeleton)"], 
      [ 'path|p=s' => "Path to create directory"]
      );
}  

sub validate_args {
  my ($self, $opt, $args) = @_;
}  
  
sub execute {
    my ($self, $opt, $args) = @_;
    
    die "Need NAME" unless defined( $args->[0] );
    my $name = $args->[0];
 
    # check for allowed characters (only letters,numbers, and -,_ )
    return print "Name may only have characters, numbers or hyphens.\n" unless( $name =~ qr/^[A-Za-z\-0-9]+$/ );
    my $tool_dev = App::Galaxy::Devel::Tool->new( dist_name_suffix => $args->[0]  );
    try {
      $tool_dev->mint_dzil;    
      if ( defined( $opt->{simple} ) ) {
        $tool_dev->make_bin_cfg_skeleton;
        
      }
      else { $tool_dev->make_app_cmd_skeleton; 
        $tool_dev->make_bin_cfg_skeleton(1);    # place name.cfg in /cfg, and name.pl in /bin
         }
    } 
    catch {
      print STDERR "Error: ", $_;      
    };
    
    print "Created distribution folder ",$tool_dev->dist_name_prefix.'-'. $args->[0], "\n";
}

1;