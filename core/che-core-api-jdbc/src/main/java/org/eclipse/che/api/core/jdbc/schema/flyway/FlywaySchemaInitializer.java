package org.eclipse.che.api.core.jdbc.schema.flyway;

import org.eclipse.che.api.core.jdbc.schema.SchemaInitializationException;
import org.eclipse.che.api.core.jdbc.schema.SchemaInitializer;
import org.flywaydb.core.Flyway;

import javax.inject.Inject;
import javax.sql.DataSource;

/**
 * <a href="https://flywaydb.org/">Flyway</a> based schema initializer.
 *
 * @author Yevhenii Voevodin
 */
public class FlywaySchemaInitializer implements SchemaInitializer {

    @Inject
    private CustomSqlMigrationResolver customResolver;

    @Inject
    private DataSource dataSource;

    @Override
    public void initialize() throws SchemaInitializationException {
        final Flyway flyway = new Flyway();
        flyway.setDataSource(dataSource);
        flyway.setLocations("sql/");
        flyway.setResolvers(customResolver);
        flyway.setSkipDefaultResolvers(true);
        flyway.setBaselineOnMigrate(true);
        flyway.setBaselineVersionAsString("");
        flyway.setSqlMigrationSeparator(".");
        flyway.setSqlMigrationSuffix(".sql");
        flyway.setSqlMigrationPrefix("");
        try {
            flyway.migrate();
        } catch (RuntimeException x) {
            throw new SchemaInitializationException(x.getLocalizedMessage(), x);
        }
    }
}
