buildscript {
    val kotlin_version by extra("1.8.22")
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:7.4.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
    }
}

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
    
    // Workaround for flutter_paystack not having namespace in Gradle 8 (Keep for safety even if 7.4.2 usually doesn't need it as strict)
    if (project.name == "flutter_paystack") {
        project.plugins.withId("com.android.library") {
            val android = project.extensions.getByType(com.android.build.gradle.LibraryExtension::class.java)
            android.namespace = "com.arttitude360.flutter_paystack"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}