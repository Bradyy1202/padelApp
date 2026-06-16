import { Module } from '@nestjs/common';
import { APP_FILTER } from '@nestjs/core';
import { AllExceptionsFilter } from './filters/all-exceptions.filter';

/**
 * Módulo transversal: filtro global de excepciones (contrato { code, message, details }).
 * Aquí se agregarán en sprints posteriores guards, interceptores y utilidades compartidas.
 */
@Module({
  providers: [
    {
      provide: APP_FILTER,
      useClass: AllExceptionsFilter,
    },
  ],
})
export class CommonModule {}
