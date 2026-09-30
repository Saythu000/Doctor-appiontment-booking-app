allprojects {
    repositories {
        google()
        mavenCentral()
    }
}


subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val kotlinTask = this
        project.gradle.taskGraph.whenReady {
            val javaCompat = project.tasks.withType<JavaCompile>().firstOrNull()?.targetCompatibility
            if (javaCompat != null) {
                if (javaCompat == "1.8" || javaCompat == "8" || javaCompat == "1.8.0") {
                    kotlinTask.compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
                } else if (javaCompat == "11" || javaCompat == "1.11") {
                    kotlinTask.compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
                } else if (javaCompat == "17") {
                    kotlinTask.compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
