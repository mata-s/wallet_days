allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")

    plugins.withId("com.android.library") {
        extensions.findByName("android")?.let { ext ->
            val getNamespace = ext.javaClass.methods.find { it.name == "getNamespace" }
            val setNamespace = ext.javaClass.methods.find { it.name == "setNamespace" }
            val namespace = getNamespace?.invoke(ext) as? String
            if (namespace.isNullOrEmpty()) {
                setNamespace?.invoke(ext, project.group.toString())
            }
        }
    }
}

subprojects {
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.glance") {
                useVersion("1.1.1")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
