package org.hellotoy.maven.plugins.assembly.mojos;

import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugin.MojoFailureException;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.ResolutionScope;
import org.apache.maven.plugins.assembly.mojos.SingleAssemblyMojo;

@Mojo( name = "edo", inheritByDefault = false, requiresDependencyResolution = ResolutionScope.TEST,
threadSafe = true )
public class ToyAssemblyMojo extends SingleAssemblyMojo{

	@Override
	public void execute() throws MojoExecutionException, MojoFailureException {
		super.execute();
	}

	@Override
	public String[] getDescriptorReferences() {
		return "hello-toy".split(" ");
	}
	
	
}
