use Module::Build;
# See perldoc Module::Build for details of how this works

Module::Build->new(
    module_name     => 'Tie::Handle::ToMemory',
    dist_author => 'David A Golden <dagolden@cpan.org>', 
    create_makefile_pl => "passthrough",
    create_readme => 1,
    license         => 'perl',
    requires => {
        # module requirements here
    },
    recommends => {},
    conflicts => {},
    build_requires  => { 
        Test::More => 0.53,
        Test::Exception => 0.19,
    },
)->create_build_script;
