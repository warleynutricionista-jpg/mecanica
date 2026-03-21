local VehicleClass = require 'client.enums.VehicleClass'

return {
    controls = {
        openMenu = 38,
        vehicleExit = 75,
    },
    vehicleClassLabels = {
        [VehicleClass.Compacts] = 'Compacto',
        [VehicleClass.Sedans] = 'Sedã',
        [VehicleClass.SUVs] = 'SUV',
        [VehicleClass.Coupes] = 'Coupé',
        [VehicleClass.Muscle] = 'Muscle',
        [VehicleClass.SportsClassics] = 'Esportivo clássico',
        [VehicleClass.Sports] = 'Esportivo',
        [VehicleClass.Super] = 'Super',
        [VehicleClass.Motorcycles] = 'Moto',
        [VehicleClass.OffRoad] = 'Off-road',
        [VehicleClass.Industrial] = 'Industrial',
        [VehicleClass.Utility] = 'Utilitário',
        [VehicleClass.Vans] = 'Van',
        [VehicleClass.Cycles] = 'Bicicleta',
        [VehicleClass.Boats] = 'Barco',
        [VehicleClass.Helicopters] = 'Helicóptero',
        [VehicleClass.Planes] = 'Avião',
        [VehicleClass.Service] = 'Serviço',
        [VehicleClass.Emergency] = 'Emergência',
        [VehicleClass.Military] = 'Militar',
        [VehicleClass.Commercial] = 'Comercial',
        [VehicleClass.Trains] = 'Trem',
        [VehicleClass.OpenWheels] = 'Open Wheel',
    },
}
