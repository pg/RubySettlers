


task :build_gui_forms do |t|
 #file 'lib/ui/wxruby/form_resource.rb' => 'lib/ui/wxruby/FormResource.xrc' do | t |
   sh "cmd.exe /c xrcise -o lib/ui/wxruby/form_resource.rb lib/ui/wxruby/FormResource.xrc"
# end    
 puts 'Generated GUI lib/ui/wxruby/form_resource.rb'
end

task :default => :build_gui_forms