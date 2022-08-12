package org.hellotoy.maven.plugins.assembly.archive.phase;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Enumeration;
import java.util.List;
import java.util.Map;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

import org.apache.commons.codec.binary.StringUtils;
import org.apache.commons.io.IOUtils;
import org.apache.maven.plugins.assembly.AssemblerConfigurationSource;
import org.apache.maven.plugins.assembly.InvalidAssemblerConfigurationException;
import org.apache.maven.plugins.assembly.archive.ArchiveCreationException;
import org.apache.maven.plugins.assembly.archive.phase.AssemblyArchiverPhase;
import org.apache.maven.plugins.assembly.archive.phase.PhaseOrder;
import org.apache.maven.plugins.assembly.archive.task.AddFileSetsTask;
import org.apache.maven.plugins.assembly.artifact.DependencyResolutionException;
import org.apache.maven.plugins.assembly.format.AssemblyFormattingException;
import org.apache.maven.plugins.assembly.model.Assembly;
import org.apache.maven.plugins.assembly.model.FileSet;
import org.codehaus.plexus.archiver.Archiver;
import org.codehaus.plexus.component.annotations.Component;
import org.codehaus.plexus.logging.AbstractLogEnabled;

@Component(role = AssemblyArchiverPhase.class, hint = "jar-file-sets")
public class JarFileSetAssemblyPhase extends AbstractLogEnabled implements AssemblyArchiverPhase, PhaseOrder {

	@Override
	public int order() {
		return Integer.MIN_VALUE;
	}

	@Override
	public void execute(Assembly assembly, Archiver archiver, AssemblerConfigurationSource configSource)
			throws ArchiveCreationException, AssemblyFormattingException, InvalidAssemblerConfigurationException,
			DependencyResolutionException {
		final List<FileSet> fileSets = assembly.getFileSets();
		if ((fileSets != null) && !fileSets.isEmpty()) {
			for (FileSet fs : fileSets) {
				reDefineJarProtocol(archiver, configSource, fs);
			}
			final AddFileSetsTask task = new AddFileSetsTask(fileSets);
			task.setLogger(getLogger());
			task.execute(archiver, configSource);
		}
	}


	private String detectOutPath(AssemblerConfigurationSource configSource, FileSet fs){
		String outPath = null;
		if(fs.getDirectory().startsWith("jar://sources")){
			outPath = configSource.getBasedir().getPath();
		} else {
			outPath = configSource.getTemporaryRootDirectory().getAbsolutePath();
		}
		if(!outPath.endsWith("/")) {
			outPath=outPath+"/";
		}
		File path = new File(outPath);
		if (!path.exists()) {
			path.mkdirs();
		}
		return outPath;
	}

	private void createParentPath(String path){
		File file = new File(path).getParentFile();
		if(!file.exists()) {
			file.mkdirs();
		}
	}


	private void reDefineJarProtocol(Archiver archiver, AssemblerConfigurationSource configSource, FileSet fs) {
		if (fs.getDirectory().startsWith("jar://")) {
			JarFile jarFile = null;
			try {
				String loadPath = fs.getDirectory().substring("jar://".length());
				String jarPath = this.getClass().getProtectionDomain().getCodeSource().getLocation().getFile();
				String outFolder = this.detectOutPath(configSource,fs);
				jarFile = new JarFile(jarPath);
				Enumeration<JarEntry> entrys = jarFile.entries();
				while (entrys.hasMoreElements()) {
					JarEntry jar = entrys.nextElement();
					String name = jar.getName();
					if (name.startsWith(loadPath+"/") && name.length()> loadPath.length()+1) {
						InputStream in = StringUtils.class.getClassLoader().getResourceAsStream(name);
						String outFile = outFolder+name;
						outFile = outFile.replace(loadPath,fs.getOutputDirectory());
						this.createParentPath(outFile);
						OutputStream out = new FileOutputStream(outFile);
						String sourceValue = IOUtils.toString(in,"UTF-8");
						sourceValue = replaceDynamicValues(configSource, sourceValue);
						IOUtils.write(sourceValue,out,"UTF-8");
						IOUtils.closeQuietly(in);
						IOUtils.closeQuietly(out);
					}
				}
				fs.setDirectory(outFolder+loadPath);
				jarFile.close();
				archiver.getDestFile();
			} catch (Exception e) {
				this.getLogger().error("copy file to temp occured error!",e);
			}finally {
				if(jarFile!=null) {
					IOUtils.closeQuietly(jarFile);
				}
			}
		}
	}

	private String replaceDynamicValues(AssemblerConfigurationSource configSource, String sourceValue) {
		configSource.getAdditionalProperties().entrySet();
		for(Map.Entry<Object, Object> entry : configSource.getAdditionalProperties().entrySet()){
			String key = String.valueOf(entry.getKey());
			String value = String.valueOf(entry.getValue());
			sourceValue = sourceValue.replaceAll("\\$\\{"+key+"\\}",value);
		}
		this.getLogger().info(configSource.getFinalName()+"===============");
		sourceValue = sourceValue.replaceAll("\\$\\{finalName\\}",configSource.getFinalName());
		return sourceValue;
	}

}
