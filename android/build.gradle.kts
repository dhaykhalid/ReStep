allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://maven.pkg.github.com/ShimmerResearch/ShimmerAndroidAPI")
            credentials {
                username = project.findProperty("gpr.usr") as String?
                password = project.findProperty("gpr.key") as String?
            }
        }
        maven {
            url = uri("https://maven.pkg.github.com/ShimmerResearch/Shimmer-Java-Android-API")
            credentials {
                username = project.findProperty("gpr.usr") as String?
                password = project.findProperty("gpr.key") as String?
            }
        }
        maven { url = uri("https://jitpack.io") }
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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}